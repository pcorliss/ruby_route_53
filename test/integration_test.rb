require 'rubygems'
require 'test/unit'
require File.dirname(__FILE__) + "/../lib/route53/cli"
require File.dirname(__FILE__) + "/../lib/route53"

route53_config = YAML.load(File.read("#{ENV['HOME']}/.route53"))

class IntegrationTest < Test::Unit::TestCase
  ZONE = "rubyroute53-#{Time.now.to_i}.example.com"
  
  def setup
    $stdin = StringIO.new
    $stdout = StringIO.new
  end
  
  def teardown
    $stdin = STDIN
    $stdout = STDOUT
  end
  
  def test_list_domains
    cli "-l"
    assert_match /\/hostedzone\//, read_stdout
  end
  
  def test_create_and_delete
    cli "-n #{ZONE}"
    assert_match /Creating New Zone #{ZONE}.*Zone Created/m, read_stdout
    
    cli "-z #{ZONE} -c --name a.#{ZONE}. --type A --ttl 60 --values 127.0.0.1"
    assert_match /Creating Record a.#{ZONE}. A 60 127.0.0.1.*Record Created./m, read_stdout
    
    cli "-z #{ZONE} -r --name a.#{ZONE}."
    assert_match /Deleting Record a.#{ZONE}.*Record Deleted/m, read_stdout

    cli "-d #{ZONE}"
    assert_match /Deleting Zone #{ZONE}/m, read_stdout
  end
  
  private
  
  def cli(arguments, input = "")
    $stdin = StringIO.new(input)
    cli = Route53::CLI.new(arguments.split, $stdin)
    cli.run
  end
  
  def read_stdout
    $stdout.rewind
    out = $stdout.read
    $stdout = StringIO.new
    out
  end
end