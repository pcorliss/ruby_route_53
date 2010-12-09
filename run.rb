#!/usr/bin/env ruby 

require 'rubygems'
require 'optparse'
require 'ostruct'
require 'date'
require 'yaml'
require './lib/route53'

class App
  
  attr_reader :options

  def initialize(arguments, stdin)
    @arguments = arguments
    @stdin = stdin
    
    # Set defaults
    @options = OpenStruct.new
    @options.verbose = false
    @options.quiet = false
  end

  # Parse options, check arguments, then process the command
  def run
    if parsed_options? && arguments_valid? 
      puts "Start at #{DateTime.now}\n\n" if @options.verbose
      
      output_options if @options.verbose # [Optional]
            
      process_arguments            
      process_command
      
      puts "\nFinished at #{DateTime.now}" if @options.verbose
      
    else
      #puts "Usage Message"
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
      
      opts.on('-l', '--list [ZONE]', String, "Receive a list of all zones or specify a zone to view") { |zone| @options.zone = zone; @options.list = true }
      opts.on('-n', '--new [ZONE]', String, "Create a new Zone") { |zone| @options.zone = zone; @options.new_zone = true }
      opts.on('-d', '--delete [ZONE]', String, "Delete a Zone") { |zone| @options.zone = zone; @options.delete_zone = true }
      opts.on('-z', '--zone [ZONE]', String, "Specify a zone to perform an operation on") { |zone| @options.zone = zone }
      
      opts.on('-c', '--create', "Create a new record") { @options.create_record = true }
      opts.on('-r', '--remove', String, "Remove a record") { |record| @options.remove_record = true }
      opts.on('-g', '--change', String, "Change a record") { |record| @options.change_record = true }
      
      opts.on('--name [NAME]', String, "Specify a name for a record") { |name| @options.name = name }
      opts.on('--type [TYPE]', String, "Specify a type for a record") { |type| @options.type = type }
      opts.on('--ttl [TTL]', String, "Specify a TTL for a record") { |ttl| @options.ttl = ttl }
      opts.on('--values [VALUE1],[VALUE2],[VALUE3]', Array, "Specify one or multiple values for a record") { |value| @options.values = value }
      
      opts.on('-m', '--comment [COMMENT]', String, "Provide a comment for this operation") { |comment| @options.comment = comment }
      
      opts.on('--no-wait',"Do not wait for actions to finish syncing.") { @options.nowait = true }
      opts.on('-s', '--setup',"Run the setup ptogram to create your configuration file.") { @options.setup = true }
      opts.on('-f', '--file [CONFIGFILE]',String,"Specify a configuration file to use") { |file| @options.file = file }
      
      opts.on('--access [ACCESSKEY]',String,"Specify an access key on the command line.") { |access| @options.access = access }
      opts.on('--secret [SECRETKEY]',String,"Specify a secret key on the command line. WARNING: Not a good idea") { |secret| @options.secret = secret }
      
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
    end
    
    def output_options
      puts "Options:\n"
      
      @options.marshal_dump.each do |name, val|        
        puts "  #{name} = #{val}"
      end
    end

    def arguments_valid?
      true #if @arguments.length == 1 
    end
    
    # Setup the arguments
    def process_arguments

      
      if @options.new_zone
        new_zone = Route53::Zone.new(@options.zone,nil,conn)
        puts "Creating New Zone #{@options.zone}"
        resp = new_zone.create_zone(@options.comment)
        if resp.error?
          $stderr.puts "ERROR: Failed to create new zone."
        else
          pending_wait(resp)
          puts "Zone Created."
        end
      end
      
      if @options.delete_zone
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
          $stderr.puts "ERROR: Couldn't Find Record for @options.zone."
        end
      end
      
      if @options.create_record
        zones = conn.get_zones(@options.zone)
        if zones.size > 0
          resps = []
          zones.each do |z|
            puts "Creating Record"
            record = Route53::DNSRecord.new(@options.name,@options.type,@options.ttl,@options.values,z)
            puts "Creating Record #{record}"
            resps.push(record.create)
          end
          resps.each do |resp|
            pending_wait(resp)
            puts "Record Created." unless resp.error?
          end
        else
          $stderr.puts "ERROR: Couldn't Find Record for @options.zone."
        end

      end
      
      if @options.remove_record
        zones = conn.get_zones(@options.zone)
        if zones.size > 0
          zones.each do |z|
            records = z.get_records(@options.type.nil? ? "ANY" : @options.type)
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
              $stderr.puts "ERROR: Couldn't Find Record for @options.zone of type "+(@options.type.nil? ? "ANY" : @options.type)+"."
            end
          end
        else
          $stderr.puts "ERROR: Couldn't Find Record for @options.zone."
        end
      end
      
      if @options.change_record
        zones = conn.get_zones(@options.zone)
        if zones.size > 0
          zones.each do |z|
            records = z.get_records(@options.type.nil? ? "ANY" : @options.type)
            if records.size > 0
              if records.size > 1
                records = record_picker(records,false)
              end
              records.each do |r| 
                puts "Modifying Record #{r.name}"
                resp = r.update(@options.name,@options.type,@options.ttl,@options.values,comment=nil)
                pending_wait(resp)
                puts "Record Modified." unless resp.error?
              end
            else
              $stderr.puts "ERROR: Couldn't Find Record for @options.zone of type "+(@options.type.nil? ? "ANY" : @options.type)+"."
            end
          end
        else
          $stderr.puts "ERROR: Couldn't Find Record for @options.zone."
        end
      end
      
      if @options.list || @options.zone.nil?
        zones = conn.get_zones(@options.zone)
        zones.each do |z|
          puts z
          if @options.zone
            records = z.get_records(@options.type.nil? ? "ANY" : @options.type)
            records.each do |r|
              puts r
            end
          end
        end
      end
    end
    
    def setup
      puts "You've either elected to run the setup or a configuration file could not be found."
      puts "Please answer the following prompts."
      new_config = Hash.new
      new_config['access_key'] = get_input(String,"Amazon Access Key",)
      new_config['secret_key'] = get_input(String,"Amazon Secret Key")
      new_config['api'] = get_input(String,"Amazon Route 53 API Version","2010-10-01")
      new_config['endpoint'] = get_input(String,"Amazon Route 53 Endpoint","https://route53.amazonaws.com/")
      if get_input(true.class,"Save the configuration file to \"~/.route53\"?","Y")
        File.open(@options.file,'w') do |out|
          YAML.dump(new_config,out)
        end
        load_config
      else
        puts "Not Saving File. Dumping Config instead."
        puts YAML.dump(new_config)
        exit 0
      end
      
    end
    
    def get_input(type,description,default = nil)
      print "#{description}: [#{default}] "
      STDOUT.flush
      selection = gets
      selection.chomp!
      if selection == ""
        selection = default
      end
      if type == true.class
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
      puts "Received #{selection}"
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
        sleep 1
      end
    end
    
    def output_version
      puts "#{File.basename(__FILE__)} version #{Route53::VERSION}"
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
        @conn = Route53::Connection.new(@config['access_key'],@config['secret_key'],@config['api'],@config['endpoint'])
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




# Create and run the application
app = App.new(ARGV, STDIN)
app.run
