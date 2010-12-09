require 'hmac'
require 'hmac-sha2'
require 'base64'
require 'time'
require 'net/http'
require 'uri'
require 'hpricot'
require 'builder'
require 'digest/md5'

module Route53
  
  class Connection
    attr_reader :base_url
    attr_reader :api
    attr_reader :endpoint
    attr_reader :verbose
    
    def initialize(accesskey,secret,api='2010-10-01',endpoint='https://route53.amazonaws.com/',verbose=false)
      @accesskey = accesskey
      @secret = secret
      @api = api
      @endpoint = endpoint
      @base_url = endpoint+@api
      @verbose = verbose
    end
    
    def request(url,type = "GET",data = nil)
      puts "URL: #{url}" if @verbose
      puts "Type: #{type}" if @verbose
      puts "Req: #{data}" if type != "GET" && @verbose
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      time = get_date
      hmac = HMAC::SHA256.new(@secret)
      hmac.update(time)
      signature = Base64.encode64(hmac.digest).chomp
      headers = {
        'Date' => time,
        'X-Amzn-Authorization' => "AWS3-HTTPS AWSAccessKeyId=#{@accesskey},Algorithm=HmacSHA256,Signature=#{signature}",
        'Content-Type' => 'text/xml; charset=UTF-8'
      }
      resp, raw_resp = http.send_request(type,uri.path,data,headers)
      #puts "Resp:"+resp.to_s if @verbose
      #puts "XML_RESP:"+raw_resp if @verbose
      return AWSResponse.new(raw_resp,self)
    end
    
    def get_zones(name = nil)
      resp = request("#{@base_url}/hostedzone")
      if resp.error?
        return nil
      end
      zone_list = Hpricot::XML(resp.raw_data)
      zones = []
      elements = zone_list.search("HostedZone")
      elements.each do |e|
        zones.push(Zone.new(e.search("Name").first.innerText,
                            e.search("Id").first.innerText,
                            self))
      end
      unless name.nil?
        name_arr = name.split('.')
        (0 ... name_arr.size).each do |i| 
          search_domain = name_arr.last(name_arr.size-i).join('.')+"."
          zone_select = zones.select { |z| z.name == search_domain }
          return zone_select if zone_select.size == 1
        end
        return nil
      end
      return zones
    end
    
    def get_date
      #return Time.now.utc.rfc2822
      #Cache date for 30 seconds to reduce extra calls
      if @date_stale.nil? || @date_stale < Time.now - 30
        uri = URI(@endpoint)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        resp = nil
        puts "Making Date Request" if @verbose
        http.start { |http| resp = http.head('/date') }
        @date = resp['Date']
        @date_stale = Time.now
        puts "Received Date." if @verbose
      end
      return @date
    end
    
  end
  
  
  class Zone
    attr_reader :host_url
    attr_reader :name
    attr_reader :records
    attr_reader :conn
    
    def initialize(name,host_url,conn)
      @name = name
      unless @name.end_with?(".")
        @name += "."
      end
      @host_url = host_url
      @conn = conn
    end
    
    def exists?
    
    end
    
    def delete_zone
      @conn.request(@conn.base_url + @host_url,"DELETE")
    end
    
    def create_zone(comment = nil)
      xml_str = ""
      xml = Builder::XmlMarkup.new(:target=>xml_str, :indent=>2)
      xml.instruct!
      xml.CreateHostedZoneRequest(:xmlns => @conn.endpoint+'doc/'+@conn.api+'/') { |create|
        create.Name(@name)
        # AWS lists this as required
        # "unique string that identifies the request and that 
        # allows failed CreateHostedZone requests to be retried without the risk of executing the operation twice."
        # Just going to pass a random string instead.
        create.CallerReference(rand().to_s)
        create.HostedZoneConfig { |conf|
          conf.Comment(comment)
        }
      }
      #puts "XML:\n#{xml_str}" if @conn.verbose
      @conn.request(@conn.base_url + "/hostedzone","POST",xml_str)
    end
    
    def get_records(type="ANY")
      return nil if host_url.nil?
      resp = @conn.request(@conn.base_url+@host_url+"/rrset")
      if resp.error?
        return nil
      end
      zone_file = Hpricot::XML(resp.raw_data)
      records = zone_file.search("ResourceRecordSet")
      
      dom_records = []
      records.each do |record|
        #puts "Name:"+record.search("Name").first.innerText if @conn.verbose
        #puts "Type:"+record.search("Type").first.innerText if @conn.verbose
        #puts "TTL:"+record.search("TTL").first.innerText if @conn.verbose
        record.search("Value").each do |val|
          #puts "Val:"+val.innerText if @conn.verbose
        end
        dom_records.push(DNSRecord.new(record.search("Name").first.innerText,
                      record.search("Type").first.innerText,
                      record.search("TTL").first.innerText,
                      record.search("Value").map { |val| val.innerText },
                      self))
      end
      @records = dom_records
      if type != 'ANY'
        return dom_records.select { |r| r.type == type }
      end
      return dom_records
    end
    
    #When deleting a record an optional value is available to specify just a single value within a recordset like an MX record
    #Takes an array of [:action => , :record => ] where action is either CREATE or DELETE and record is a DNSRecord
    def gen_change_xml(change_list,comment=nil)
      #Get zone list and pick zone that matches most ending chars

      xml_str = ""
      xml = Builder::XmlMarkup.new(:target=>xml_str, :indent=>2)
      xml.instruct!
      xml.ChangeResourceRecordSetsRequest(:xmlns => @conn.endpoint+'doc/'+@conn.api+'/') { |req|
        req.ChangeBatch { |batch|
          batch.Comment(comment) unless comment.nil?
          batch.Changes { |changes|
            change_list.each { |change_item|
              change_item[:record].gen_change_xml(changes,change_item[:action])
            }
          }
        }
      }
      #puts "XML:\n#{xml_str}" if @conn.verbose
      return xml_str
    end
    
    #For modifying multiple or single records within a single transaction
    def perform_actions(change_list,comment=nil)
      xml_str = gen_change_xml(change_list,comment)
      @conn.request(@conn.base_url + @host_url+"/rrset","POST",xml_str)
    end

    
    def to_s
      return "#{@name} #{@host_url}"
    end
  end
  
  class AWSResponse
    attr_reader :raw_data
    def initialize(resp,conn)
      @raw_data = resp
      if error?
        $stderr.puts "An Error has occured"
        $stderr.puts @raw_data
      end
      @conn = conn
      puts "Raw: #{@raw_data}" if @conn.verbose
    end
    
    def error?
      return Hpricot::XML(@raw_data).search("ErrorResponse").size > 0
    end

    def complete?
      return true if error?
      if @change_url.nil?
        change = Hpricot::XML(@raw_data).search("ChangeInfo")
        if change.size > 0
          @change_url = change.first.search("Id").first.innerText
        else
          return false
        end
      end
      if @complete.nil? || @complete == false
        status = Hpricot::XML(@conn.request(@conn.base_url+@change_url).raw_data).search("Status")
        @complete = status.size > 0 && status.first.innerText == "INSYNC" ? true : false
      end
      return @complete
    end
    
    def pending?
      #Return opposite of complete via XOR
      return complete? ^ true
    end
    
    def to_s
      return @raw_data
    end
  end
  
  class DNSRecord
    attr_reader :name
    attr_reader :type
    attr_reader :ttl
    attr_reader :values
    
    def initialize(name,type,ttl,values,zone)
      @name = name
      @type = type
      @ttl = ttl
      @values = values
      @zone = zone
    end
    
    def gen_change_xml(xml,action)
      xml.Change { |change|
        change.Action(action.upcase)
        change.ResourceRecordSet { |record|
          record.Name(@name)
          record.Type(@type)
          record.TTL(@ttl)
          record.ResourceRecords { |resources|
            @values.each { |val|
              resources.ResourceRecord { |record|
                record.Value(val)
              }
            }
          }
        }
      }
    end
    
    def delete(comment=nil)
      @zone.perform_actions([{:action => "DELETE", :record => self}],comment)
    end
    
    def create(comment=nil)
      @zone.perform_actions([{:action => "CREATE", :record => self}],comment)
    end
    
    #Need to modify to a param hash
    def update(name,type,ttl,values,comment=nil)
      prev = self.clone
      @name = name unless name.nil?
      @type = type unless type.nil?
      @ttl = ttl unless ttl.nil?
      @values = values unless values.nil?
      @zone.perform_actions([
          {:action => "DELETE", :record => prev},
          {:action => "CREATE", :record => self},
          ],comment)
    end
    
    #Returns the raw array so the developer can update large batches manually
    #Need to modify to a param hash
    def update_dirty(name,type,ttl,values)
      prev = self.clone
      @name = name unless name.nil?
      @type = type unless type.nil?
      @ttl = ttl unless ttl.nil?
      @values = values unless values.nil?
      return [{:action => "DELETE", :record => prev},
      {:action => "CREATE", :record => self}]
    end
    
    def to_s
      return "#{@name} #{@type} #{@ttl} #{@values}"
    end
  end
end


