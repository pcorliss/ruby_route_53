
require 'rubygems'
require 'optparse'
require 'ostruct'
require 'date'
require 'yaml'

module Route53
  class CLI
    
    attr_reader :options

    def initialize(arguments, stdin)
      @arguments = arguments
      @stdin = stdin
      
      # Set defaults
      @options = OpenStruct.new
      @options.verbose = false
      @options.quiet = false
    end

    #Skeleton obtained from http://blog.toddwerth.com/entries/show/5 and modified
    
    # Parse options, check arguments, then process the command
    def run
      if parsed_options? && arguments_valid? 
        puts "Start at #{DateTime.now}\n\n" if @options.verbose
        
        output_options if @options.verbose # [Optional]
              
        process_arguments            
        process_command
        
        puts "\nFinished at #{DateTime.now}" if @options.verbose
        
      else
        puts "ERROR: Invalid Options passed. Please run with --help"
        exit 1
      end
        
    end
    
    protected
    
      def parsed_options?
        
        # Specify options
        opts = OptionParser.new 
        opts.on('-v', '--version', "Print Version Information") { output_version ; exit 0 }
        opts.on('-h', '--help',"Show this message") { puts opts ; exit 0 }
        opts.on('-V', '--verbose',"Verbose Output") { @options.verbose = true }  
        #opts.on('-q', '--quiet',"Quiet Output") { @options.quiet = true }
        
        opts.on('-l', '--list [ZONE]', String, "Receive a list of all zones or specify a zone to view") { |zone| @options.zone = zone unless zone.nil?; @options.list = true }
        opts.on('-n', '--new [ZONE]', String, "Create a new Zone") { |zone| @options.zone = zone unless zone.nil?; @options.new_zone = true }
        opts.on('-d', '--delete [ZONE]', String, "Delete a Zone") { |zone| @options.zone = zone unless zone.nil?; @options.delete_zone = true }
        opts.on('-z', '--zone [ZONE]', String, "Specify a zone to perform an operation on. Either in 'example.com.' or '/hostedzone/XXX' format") { |zone| @options.zone = zone }
        
        opts.on('-c', '--create', "Create a new record") { @options.create_record = true }
        
        opts.on('-r', '--remove', String, "Remove a record") { |record| @options.remove_record = true }
        opts.on('-g', '--change', String, "Change a record") { |record| @options.change_record = true }
        
        opts.on('--name [NAME]', String, "Specify a name for a record") { |name| @options.name = name }
        opts.on('--type [TYPE]', String, "Specify a type for a record") { |dnstype| @options.dnstype = dnstype }
        opts.on('--ttl [TTL]', String, "Specify a TTL for a record") { |ttl| @options.ttl = ttl }
        opts.on('--weight [WEIGHT]', String, "Specify a Weight for a record") { |weight| @options.weight = weight }
        opts.on('--ident [IDENTIFIER]', String, "Specify a unique identifier for a record") { |ident| @options.ident = ident }
        opts.on('--values [VALUE1],[VALUE2],[VALUE3]', Array, "Specify one or multiple values for a record") { |value| @options.values = value }
        opts.on('--zone-apex-id [ZONE_APEX_ID]', String, "Specify a zone apex if for the record") { |zone_apex| @options.zone_apex = zone_apex || false }
        
        opts.on('-m', '--comment [COMMENT]', String, "Provide a comment for this operation") { |comment| @options.comment = comment }
        
        opts.on('--no-wait',"Do not wait for actions to finish syncing.") { @options.nowait = true }
        opts.on('-s', '--setup',"Run the setup ptogram to create your configuration file.") { @options.setup = true }
        opts.on('-f', '--file [CONFIGFILE]',String,"Specify a configuration file to use") { |file| @options.file = file }
        
        opts.on('--access [ACCESSKEY]',String,"Specify an access key on the command line.") { |access| @options.access = access }
        opts.on('--secret [SECRETKEY]',String,"Specify a secret key on the command line. WARNING: Not a good idea") { |secret| @options.secret = secret }
        
        opts.on('--no-upgrade',"Do not automatically upgrade the route53 api spec for this version.") { @options.no_upgrade = true }
        
        opts.parse!(@arguments) rescue return false
        
        process_options
        true
      end

      # Performs post-parse processing on options
      def process_options
        @options.verbose = false if @options.quiet
        @options.file = (user_home+"/.route53") if @options.file.nil?
        #setup file
        if @options.setup
          setup
        end
        load_config
        @config['access_key'] = @options.access unless @options.access.nil?
        @config['secret_key'] = @options.secret unless @options.secret.nil?
        
        
        required_options("",["--access-key"]) if @config['access_key'].nil? || @config['access_key'] == ""
        required_options("",["--secret_key"]) if @config['secret_key'].nil? || @config['secret_key'] == ""
        
      end
      
      def output_options
        puts "Options:\n"
        
        @options.marshal_dump.each do |name, val|        
          puts "  #{name} = #{val}"
        end
      end

      def arguments_valid?
        if @arguments.length <= 1
          @options.zone = @arguments.pop if @options.zone.nil?
          return true
        else
          $stderr.puts "Received extra arguments. that couldn't be handled:#{@arguments}"
          return false
        end
      end
      
      # Setup the arguments
      def process_arguments
        if @options.new_zone
          new_zone
        elsif @options.delete_zone
          delete_zone
        elsif @options.create_record
          create_record
        elsif @options.remove_record 
          remove_record
        elsif @options.change_record
          change_record
        else
          list
        end
      end
      
      def list
        zones = conn.get_zones(@options.zone)
        unless zones.nil?
          zones.each do |z|
            puts z
            if @options.zone
              records = z.get_records(@options.dnstype.nil? ? "ANY" : @options.dnstype)
              records.each do |r|
                puts r
              end
            end
          end
        else
          $stderr.puts "ERROR: No Records found for #{@options.zone}"
        end
      end
    
      def new_zone
        if @options.zone
          new_zone = Route53::Zone.new(@options.zone,nil,conn)
          puts "Creating New Zone #{@options.zone}"
          resp = new_zone.create_zone(@options.comment)
          if resp.error?
            $stderr.puts "ERROR: Failed to create new zone."
          else
            pending_wait(resp)
            puts "Zone Created."
          end
        else
          required_options("new zone",["--zone"])
        end
      end
      
      def delete_zone
        if @options.zone
          records = conn.get_zones(@options.zone)
          if records.size > 0
            if records.size > 1
              records = record_picker(records)
            end
            records.each do |r| 
              puts "Deleting Zone #{r.name}"
              resp = r.delete_zone
              pending_wait(resp)
              puts "Zone Deleted." unless resp.error?
            end
          else
            $stderr.puts "ERROR: Couldn't Find Record for #{@options.zone}."
          end
        else
          required_options("delete zone",["--zone"])
        end
      end
      
      def create_record
        if @options.zone && @options.name && 
           @options.dnstype && @options.values && 
           (@options.ttl || @config['default_ttl'])
          zones = conn.get_zones(@options.zone)
          if zones.size > 0
            resps = []
            zones.each do |z|
              puts "Creating Record"
              @options.ttl = @config['default_ttl'] if @options.ttl.nil?
              if @options.dnstype.upcase == 'TXT'
                @options.values = @options.values.map do |val|
                  unless val.start_with?('"') && val.end_with?('"')
                    val = '"' + val unless val.start_with? '"'
                    val = val + '"' unless val.end_with? '"'
                  end
                  val
                end
              end
              record = Route53::DNSRecord.new(@options.name,@options.dnstype,@options.ttl,@options.values,z,@options.zone_apex,@options.weight,@options.ident)
              puts "Creating Record #{record}"
              resps.push(record.create)
            end
            resps.each do |resp|
              pending_wait(resp)
              puts "Record Created." unless resp.error?
            end
          else
            $stderr.puts "ERROR: Couldn't Find Record for #{@options.zone}."
          end
        else
          #$stderr.puts "ERROR: The following arguments are required for a create record operation."
          #$stderr.puts "ERROR: --zone and at least one of --name, --type, --ttl or --values"
          #exit 1
          required_options("create record",["--zone","--name","--type","--ttl","--values"])
        end
      end
      
      def remove_record
        if @options.zone
          zones = conn.get_zones(@options.zone)
          if zones.size > 0
            zones.each do |z|
              records = z.get_records(@options.dnstype.nil? ? "ANY" : @options.dnstype)
              records = records.select { |rec| rec.name == @options.name } if @options.name
              if records.size > 0
                if records.size > 1
                  records = record_picker(records)
                end
                records.each do |r| 
                  puts "Deleting Record #{r.name}"
                  resp = r.delete
                  pending_wait(resp)
                  puts "Record Deleted." unless resp.error?
                end
              else
                $stderr.puts "ERROR: Couldn't Find Record for #{@options.zone} of type "+(@options.dnstype.nil? ? "ANY" : @options.dnstype)+"."
              end
            end
          else
            $stderr.puts "ERROR: Couldn't Find Record for #{@options.zone}."
          end
        else
          #$stderr.puts "ERROR: The following arguments are required for a record removal operation."
          #$stderr.puts "ERROR: --zone"
          #exit 1
          required_options("record removal",["--zone"])
        end
      end
      
      def change_record
        if @options.zone && (@options.name || @options.dnstype || @options.ttl || @options.values)
          zones = conn.get_zones(@options.zone)
          if zones.size > 0
            zones.each do |z|
              records = z.get_records(@options.dnstype.nil? ? "ANY" : @options.dnstype)
              records = records.select { |rec|  puts "Rec: #{rec.name}"; rec.name == @options.name } if @options.name
              if records.size > 0
                if records.size > 1
                  records = record_picker(records,false)
                end
                records.each do |r| 
                  puts "Modifying Record #{r.name}"
                  if !@options.zone_apex.nil? && !@options.zone_apex && @options.ttl.nil?
                    $stderr.puts "ERROR: must provide --ttl if --zone_apex is set to empty string"
                    exit 1
                  end
                  resp = r.update(@options.name,@options.dnstype,@options.ttl,@options.values,comment=nil,@options.zone_apex)
                  pending_wait(resp)
                  puts "Record Modified." unless resp.error?
                end
              else
                $stderr.puts "ERROR: Couldn't Find Record for #{@options.name} of type "+(@options.dnstype.nil? ? "ANY" : @options.dnstype)+"."
              end
            end
          else
            $stderr.puts "ERROR: Couldn't Find Record for #{@options.name}."
          end
        else
          #$stderr.puts "ERROR: The following arguments are required for a record change operation."
          #$stderr.puts "ERROR: --zone and at least one of --name, --type, --ttl or --values"
          #exit 1
          required_options("record change",["--zone"],["--name","--type","--ttl","--values"])
        end
      end
      
      def required_options(operation,required = [],at_least_one = [],optional = [])
        operation == "" ? operation += " " : operation = " "+operation+" "
        $stderr.puts "ERROR: The following arguments are required for a#{operation}operation."
        $stderr.puts "ERROR: #{required.join(", ")} #{ (required.size > 1 ? "are" : "is") } required." if required.size > 0
        $stderr.puts "ERROR: At least one of #{at_least_one.join(", ")} are required." if at_least_one.size > 0
        $stderr.puts "ERROR: #{optional.join(", ")}are optional." if optional.size > 0
        exit 1
      end
      
      def setup
        puts "You've either elected to run the setup or a configuration file could not be found."
        puts "Please answer the following prompts."
        new_config = Hash.new
        new_config['access_key'] = get_input(String,"Amazon Access Key")
        new_config['secret_key'] = get_input(String,"Amazon Secret Key")
        new_config['api'] = get_input(String,"Amazon Route 53 API Version","2011-05-05")
        new_config['endpoint'] = get_input(String,"Amazon Route 53 Endpoint","https://route53.amazonaws.com/")
        new_config['default_ttl'] = get_input(String,"Default TTL","3600")
        if get_input(true.class,"Save the configuration file to \"~/.route53\"?","Y")
          File.open(@options.file,'w') do |out|
            YAML.dump(new_config,out)
          end
          File.chmod(0600,@options.file)
          load_config
        else
          puts "Not Saving File. Dumping Config instead."
          puts YAML.dump(new_config)
          exit 0
        end
        
      end
      
      def get_input(inputtype,description,default = nil)
        print "#{description}: [#{default}] "
        STDOUT.flush
        selection = gets
        selection.chomp!
        if selection == ""
          selection = default
        end
        if inputtype == true.class
          selection = (selection == 'Y')
        end
        return selection
      end
      
      def record_picker(records,allowall = true)
        puts "Please select the record to perform the action on."
        records.each_with_index do |r,i|
          puts "[#{i}] #{r}"
        end
        puts "[#{records.size}] All" if allowall
        puts "[#{records.size+1}] None"
        print "Make a selection: [#{records.size+1}] "
        STDOUT.flush
        selection = gets
        selection.chomp!
        if selection == ""
          selection = records.size+1
        elsif selection != "0" && selection.to_i == 0
          $stderr.puts "a Invalid selection: #{selection}"
          exit 1
        end
        selection = selection.to_i
        if selection == records.size && allowall
          return records
        elsif selection == records.size + 1
          return []
        elsif records[selection]
          return [records[selection]]
        else
          $stderr.puts "Invalid selection: #{selection}"
          exit 1
        end
      end
      
      def pending_wait(resp)
        while !@options.nowait && resp.pending?
          print '.'
          
          STDOUT.flush
          sleep 1
        end
      end
      
      def output_version
        puts "Ruby route53 interface version #{Route53::VERSION}"
        puts "Written by Philip Corliss (pcorliss@50projects.com)"
        puts "https://github.com/pcorliss/ruby_route_53"
      end
      
      def process_command

      end

      def process_standard_input
        input = @stdin.read      
        #@stdin.each do |line| 
        #  
        #end
      end
      
      def conn
        if @conn.nil?
          @conn = Route53::Connection.new(@config['access_key'],@config['secret_key'],@config['api'],@config['endpoint'],@options.verbose)
        end
        return @conn
      end
      
      def load_config
        unless File.exists?(@options.file)
          setup
        end
        @config = YAML.load_file(@options.file)
        unless @config
          @config = Hash.new
        end
        if @config['api'] != '2011-05-05' && !@options.no_upgrade
          puts "Note: Automatically setting your configuration file to the amazon route 53 api spec this program was written for. You can avoid this by passing --no-upgrade"
          @config['api'] = '2011-05-05'
          File.open(@options.file,'w') do |out|
            YAML.dump(@config,out)
          end
          File.chmod(0600,@options.file)
        end
      end
      
      def user_home
        homes = ["HOME", "HOMEPATH"]
        realHome = homes.detect {|h| ENV[h] != nil}
        if not realHome
           $stderr.puts "Could not find home directory"
        end
        return ENV[realHome]
      end
  end
end
