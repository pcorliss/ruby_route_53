module Route53
  class AWSResponse
    attr_reader :raw_data

    MESSAGES = {
      "InvalidClientTokenId" => "You may have a missing or incorrect secret or access key. Please double check your configuration files and amazon account",
      "MissingAuthenticationToken" => "You may have a missing or incorrect secret or access key. Please double check your configuration files and amazon account",
      "OptInRequired" => "In order to use Amazon's Route 53 service you first need to signup for it. Please see http://aws.amazon.com/route53/ for your account information and use the associated access key and secret.",
      "Other" => "It looks like you've run into an unhandled error. Please send a detailed bug report with the entire input and output from the program to support@50projects.com or to https://github.com/pcorliss/ruby_route_53/issues and we'll do out best to help you.",
      "SignatureDoesNotMatch" => "It looks like your secret key is incorrect or no longer valid. Please check your amazon account information for the proper key.",
      "HostedZoneNotEmpty" => "You'll need to first delete the contents of this zone. You can do so using the '--remove' option as part of the command line interface.",
      "InvalidChangeBatch" => "You may have tried to delete a NS or SOA record. This error is safe to ignore if you're just trying to delete all records as part of a zone prior to deleting the zone. Or you may have tried to create a record that already exists. Otherwise please file a bug by sending a detailed bug report with the entire input and output from the program to support@50projects.com or to https://github.com/pcorliss/ruby_route_53/issues and we'll do out best to help you.",
      "ValidationError" => "Check over your input again to make sure the record to be created is valid. The error message should give you some hints on what went wrong. If you're still having problems please file a bug by sending a detailed bug report with the entire input and output from the program to support@50projects.com or to https://github.com/pcorliss/ruby_route_53/issues and we'll do out best to help you.",
      "ServiceUnavailable" => "It looks like Amazon Route 53 is having availability problems. If the error persists, you may want to check http://status.aws.amazon.com/ for more information on the current system status."
    }

    def initialize(resp,conn)
      @raw_data = unescape(resp)
      if error?
        $stderr.puts "ERROR: Amazon returned an error for the request."
        $stderr.puts "ERROR: RAW_XML: "+@raw_data
        $stderr.puts "ERROR: "+error_message
        $stderr.puts ""
        $stderr.puts "What now? "+helpful_message
        #exit 1
      end
      @conn = conn
      @created = Time.now
      puts "Raw: #{@raw_data}" if @conn.verbose
    end

    def error?
      return Nokogiri::XML(@raw_data).search("ErrorResponse").size > 0
    end

    def error_message
      xml = Nokogiri::XML(@raw_data)
      msg_code = xml.search("Code")
      msg_text = xml.search("Message")
      return (msg_code.size > 0 ? msg_code.first.inner_text : "") + (msg_text.size > 0 ? ': ' + msg_text.first.inner_text : "")
    end

    def helpful_message
      xml = Nokogiri::XML(@raw_data)
      msg_code = xml.search("Code").first.inner_text
      MESSAGES[msg_code] || MESSAGES["Other"]
    end

    def complete?
      return true if error?
      if @change_url.nil?
        change = Nokogiri::XML(@raw_data).search("ChangeInfo")
        if change.size > 0
          @change_url = change.first.search("Id").first.inner_text
        else
          return false
        end
      end
      if @complete.nil? || @complete == false
        status = Nokogiri::XML(@conn.request(@conn.base_url+@change_url).raw_data).search("Status")
        @complete = status.size > 0 && status.first.inner_text == "INSYNC" ? true : false
        if !@complete && @created - Time.now > 60
          $stderr.puts "WARNING: Amazon Route53 Change timed out on Sync. This may not be an issue as it may just be Amazon being assy. Then again your request may not have completed.'"
          @complete = true
        end
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

    def unescape(string)
      string.gsub(/\\0(\d{2})/) { $1.oct.chr }
    end
  end
end
