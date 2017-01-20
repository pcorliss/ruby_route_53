module Route53
  class Connection
    attr_reader :base_url
    attr_reader :api
    attr_reader :endpoint
    attr_reader :verbose

    def initialize(accesskey,secret,api='2012-12-12',endpoint='https://route53.amazonaws.com/',verbose=false,ssl_no_verify=false)
      @accesskey = accesskey
      @secret = secret
      @api = api
      @endpoint = endpoint
      @base_url = endpoint+@api
      @verbose = verbose
      @ssl_no_verify = ssl_no_verify
    end

    def request(url,type = "GET",data = nil)
      puts "URL: #{url}" if @verbose
      puts "Type: #{type}" if @verbose
      puts "Req: #{data}" if type != "GET" && @verbose
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == "https"
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if RUBY_VERSION.start_with?("1.8") or @ssl_no_verify
      time = get_date
      hmac = HMAC::SHA256.new(@secret)
      hmac.update(time)
      signature = Base64.encode64(hmac.digest).chomp
      headers = {
        'Date' => time,
        'X-Amzn-Authorization' => "AWS3-HTTPS AWSAccessKeyId=#{@accesskey},Algorithm=HmacSHA256,Signature=#{signature}",
        'Content-Type' => 'text/xml; charset=UTF-8'
      }
      resp = http.send_request(type,uri.path+"?"+(uri.query.nil? ? "" : uri.query),data,headers)
      #puts "Resp:"+resp.to_s if @verbose
      #puts "RespBody: #{resp.body}" if @verbose
      return AWSResponse.new(resp.body,self)
    end

    def get_zones(name = nil)
      truncated = true
      query = []
      zones = []
      while truncated
        if !name.nil? && name.start_with?("/hostedzone/")
          resp = request("#{@base_url}#{name}")
          truncated = false
        else
          resp = request("#{@base_url}/hostedzone?"+query.join("&"))
        end
        return nil if resp.error?
        zone_list = Nokogiri::XML(resp.raw_data)
        elements = zone_list.search("HostedZone")
        elements.each do |e|
          zones.push(Zone.new(e.search("Name").first.inner_text,
                              e.search("Id").first.inner_text,
                              self))
        end
        truncated = (zone_list.search("IsTruncated").first.inner_text == "true") if truncated
        query = ["marker="+zone_list.search("NextMarker").first.inner_text] if truncated
      end
      unless name.nil? || name.start_with?("/hostedzone/")
        name_arr = name.split('.')
        (0 ... name_arr.size).each do |i|
          search_domain = name_arr.last(name_arr.size-i).join('.')+"."
          zone_select = zones.select { |z| z.name == search_domain }
          return zone_select if zone_select.any?
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
        http.use_ssl = true if uri.scheme == "https"
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if RUBY_VERSION.start_with?("1.8") or @ssl_no_verify
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
end
