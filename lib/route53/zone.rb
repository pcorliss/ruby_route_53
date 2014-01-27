module Route53
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

    def nameservers
      return @nameservers if @nameservers
      response = Nokogiri::XML(@conn.request(@conn.base_url + @host_url).to_s)
      @nameservers = response.search("NameServer").map(&:inner_text)
      @nameservers
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
        create.CallerReference(rand(2**32).to_s(16))
        create.HostedZoneConfig { |conf|
          conf.Comment(comment)
        }
      }
      #puts "XML:\n#{xml_str}" if @conn.verbose
      resp = @conn.request(@conn.base_url + "/hostedzone","POST",xml_str)
      resp_xml = Nokogiri::XML(resp.raw_data)
      @host_url = resp_xml.search("HostedZone").first.search("Id").first.inner_text
      return resp
    end

    def get_records(type="ANY")
      return nil if host_url.nil?

      truncated = true
      query = []
      dom_records = []
      while truncated
        resp = @conn.request(@conn.base_url+@host_url+"/rrset?"+query.join("&"))
        if resp.error?
          return nil
        end
        zone_file = Nokogiri::XML(resp.raw_data)
        records = zone_file.search("ResourceRecordSet")

        records.each do |record|
          #puts "Name:"+record.search("Name").first.inner_text if @conn.verbose
          #puts "Type:"+record.search("Type").first.inner_text if @conn.verbose
          #puts "TTL:"+record.search("TTL").first.inner_text if @conn.verbose
          #record.search("Value").each do |val|
          #  #puts "Val:"+val.inner_text if @conn.verbose
          #end
          zone_apex_records = record.search("HostedZoneId")
          values = record.search("Value").map { |val| val.inner_text }
          values << record.search("DNSName").first.inner_text unless zone_apex_records.empty?
          weight_records = record.search("Weight")
          ident_records = record.search("SetIdentifier")
          dom_records.push(DNSRecord.new(record.search("Name").first.inner_text,
                        record.search("Type").first.inner_text,
                        ((record.search("TTL").first.nil? ? '' : record.search("TTL").first.inner_text) if zone_apex_records.empty?),
                        values,
                        self,
                        (zone_apex_records.first.inner_text unless zone_apex_records.empty?),
                        (weight_records.first.inner_text unless weight_records.empty?),
                        (ident_records.first.inner_text unless ident_records.empty?)
                        ))
        end

        truncated = (zone_file.search("IsTruncated").first.inner_text == "true")
        if truncated
          next_name = zone_file.search("NextRecordName").first.inner_text
          next_type = zone_file.search("NextRecordType").first.inner_text
          query = ["name="+next_name,"type="+next_type]
        end
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
end
