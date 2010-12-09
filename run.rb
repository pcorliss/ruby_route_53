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
      opts.on('-q', '--quiet',"Quiet Output") { @options.quiet = true }
      
      opts.on('-l', '--list [ZONE]', String, "Receive a list of all zones or specify a zone to view") { |zone| @options.zone = zone; @options.list = true }
      opts.on('-n', '--new [ZONE]', String, "Create a new Zone") { |zone| @options.zone = zone; @options.new_zone = true }
      opts.on('-d', '--delete [ZONE]', String, "Delete a Zone") { |zone| @options.zone = zone; @options.delete_zone = true }
      opts.on('-z', '--zone [ZONE]', String, "Specify a zone to perform an operation on") { |zone| @options.zone = zone }
      
      opts.on('-c', '--create', "Create a new record") { @options.create_record = true }
      opts.on('-r', '--remove [RECORD]', String, "Remove a record") { |record| @options.remove_record = record }
      opts.on('-g', '--change [RECORD]', String, "Change a record") { |record| @options.change_record = record }
      
      opts.on('--name [NAME]', String, "Specify a name for a record") { |name| @options.name = name }
      opts.on('--type [TYPE]', String, "Specify a type for a record") { |type| @options.type = type }
      opts.on('--ttl [TTL]', String, "Specify a TTL for a record") { |ttl| @options.ttl = ttl }
      opts.on('--value [VALUE]', String, "Specify a value for a record") { |value| @options.value = value }
      
      opts.on('-m', '--comment [COMMENT]', String, "Provide a comment for this operation") { |comment| @options.comment = comment }
            
      opts.on('-s', '--setup',"Run the setup ptogram to create your configuration file.")
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
      if @options.list
        records = conn.get_zones(@options.zone)
        records.each do |r|
          puts r
        end
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
