Ruby Interface for Amazon's Route 53
====================================

This interface can either be used as a command line tool or as a library from within your existing ruby project. It provides a way to interact with Amazon's Route 53 service.

Costs & Impact
--------------

At the time of this writing Amazon charges $1/zone/month. This includes zones that have been created and deleted and then recreated outside of the normal 12 hour grace period. The creator of this gem is not responsible for costs incurred while using this interface or unexpected oepration or bugs which may incur a cost for the user. The creator is also not responsible for any downtime incurred or disruption in service from the usage of this tool. DNS can be a tricky thing, be careful and always make sure you have a backup of your zone prior to mucking around with it. (route53 -l example.com.)

Latest Version
--------------

The latest source should be available on my [github account](https://github.com/pcorliss/ruby_route_53) and if you can't obtain it using the gem command you can go directly to the [gem page](https://rubygems.org/gems/route53) hosted on rubygems.

Installation
------------

Installing the Gem

```bash
sudo gem install route53
```

Ubuntu with precompiled dependencies

```bash
sudo apt-get update
sudo apt-get install ruby rubygems libopenssl-ruby libhmac-ruby libbuilder-ruby libhpricot-ruby
sudo gem install route53 --ignore-dependencies
/var/lib/gems/1.X/gems/route53-W.Y.Z/bin/route53

#When working with the library and using this method you may need to require the library manually
require '/var/lib/gems/1.X/gems/route53-W.Y.Z/lib/route53'
```
    
Ubuntu with building dependencies

```bash
sudo apt-get update
sudo apt-get install ruby rubygems ruby-dev build-essential libopenssl-ruby
sudo gem install route53
/var/lib/gems/1.X/bin/route53
```
    
The first time you run the gem in command line mode you'll be prompted to setup. You'll want to have your Amazon access and secret key ready.

    You've either elected to run the setup or a configuration file could not be found.
    Please answer the following prompts.
    Amazon Access Key: []
    Amazon Secret Key: []
    Amazon Route 53 API Version: [2011-05-05]
    Amazon Route 53 Endpoint: [https://route53.amazonaws.com/]
    Default TTL: [3600]
    Save the configuration file to "~/.route53"?: [Y]

Command Line Options
--------------------

    Usage: route53 [options]
    
    -v, --version                    Print Version Information
    -h, --help                       Show this message
    -V, --verbose                    Verbose Output
    -l, --list [ZONE]                Receive a list of all zones or specify a zone to view
    -n, --new [ZONE]                 Create a new Zone
    -d, --delete [ZONE]              Delete a Zone
    -z, --zone [ZONE]                Specify a zone to perform an operation on. Either in 'example.com.' or '/hostedzone/XXX' format
    -c, --create                     Create a new record
    -r, --remove                     Remove a record
    -g, --change                     Change a record
        --name [NAME]                Specify a name for a record
        --type [TYPE]                Specify a type for a record
        --ttl [TTL]                  Specify a TTL for a record
        --weight [WEIGHT]            Specify a Weight for a record
        --ident [IDENTIFIER]         Specify a unique identifier for a record
        --values [VALUE1],[VALUE2],[VALUE3]
                                     Specify one or multiple values for a record
        --zone-apex-id [ZONE_APEX_ID]
                                     Specify a zone apex if for the record
    -m, --comment [COMMENT]          Provide a comment for this operation
        --no-wait                    Do not wait for actions to finish syncing.
    -s, --setup                      Run the setup ptogram to create your configuration file.
    -f, --file [CONFIGFILE]          Specify a configuration file to use
        --access [ACCESSKEY]         Specify an access key on the command line.
        --secret [SECRETKEY]         Specify a secret key on the command line. WARNING: Not a good idea
        --no-upgrade                 Do not automatically upgrade the route53 api spec for this version.

Command Line Usage
------------------

Once route53 is installed, started and has been setup you're ready to start. You can use the following examples to get started.

```bash
#Creating a new zone
route53 -n example.com.

#List Operations
route53 -l #Get all zones for this account
route53 -l example.com. #Get all records for this account within the zone example.com.

#Create a new record within our newly created zone.
route53 --zone example.com. -c --name foo.example.com. --type CNAME --ttl 3600 --values example.com.

#New MX Record for a Google Apps hosted domain
route53 --zone example.com. -c --name example.com. --type MX --ttl 3600 \
--values "10 ASPMX.L.GOOGLE.com.","20 ALT1.ASPMX.L.GOOGLE.com.","30 ALT2.ASPMX.L.GOOGLE.com.","40 ASPMX2.GOOGLEMAIL.com.","50 ASPMX3.GOOGLEMAIL.com."

#Update the TTL of a record (Leave values nil to leave them alone)
#You'll be prompted to select the record from a list.
#If updating values for a record, make sure to includ all other values. Otherwise they will be dropped
route53 --zone example.com. -g --ttl 600

#Creating a record that corresponds to an Amazon ELB (zone apex support)
route53 --zone example.com. -c --name example. --zone-apex-id Z3DZXE0XXXXXXX --type A --values my-load-balancer-XXXXXXX.us-east-1.elb.amazonaws.com

#Creating weighted record sets
route53 example.com. -c --name www.example.com. --weight 15 --ident "75 percent of traffic to pool1" --type CNAME --values pool1.example.com.
route53 example.com. -c --name www.example.com. --weight 5 --ident "25 percent of traffic to pool2" --type CNAME --values pool2.example.com.

#Creating a wildcard domain
route53 example.com. -c --name *.example.com --type CNAME --values pool1.example.com.

#Deleting a zone - First remove all records except the NS and SOA record. Then delete the zone.
route53 --zone example.com. -r
route53 -d example.com.
```    

Library Usage
-------------

If you're using this as a library for your own ruby project you can load it and perform operations by using the following examples.

```ruby
require 'route53'

#Creating a Connection object
conn = Route53::Connection.new(my_access_key,my_secret_key) #opens connection

#Creating a new zone and working with responses
new_zone = Route53::Zone.new("example.com.",nil,conn) #Create a new zone "example.com."
resp = new_zone.create_zone #Creates a new zone
exit 1 if resp.error? #Exit if there was an error. The AWSResponse Class automatically prints out error messages to STDERR.
while resp.pending? #Waits for response to sync on Amazon's servers.
  sleep 1 #If you'll be performing operations on this newly created zone you'll probably want to wait.
end

#List Operations
zones = conn.get_zones #Requests list of all zones for this account
records = zones.first.get_records #Gets list of all records for a specific zone

#Create a new record within our newly created zone.
new_record = Route53::DNSRecord.new("foo.example.com.","CNAME","3600",["example.com."],new_zone)
resp = new_record.create 

#New MX Record for a Google Apps hosted domain
new_mx_record = Route53::DNSRecord.new("example.com.","MX","3600",
                  ["10 ASPMX.L.GOOGLE.com.",
                  "20 ALT1.ASPMX.L.GOOGLE.com.",
                  "30 ALT2.ASPMX.L.GOOGLE.com.",
                  "40 ASPMX2.GOOGLEMAIL.com.",
                  "50 ASPMX3.GOOGLEMAIL.com."],
                  new_zone)
resp = new_mx_record.create

#Update the TTL of a record (Leave values nil to leave them alone)
#If updating values for a record, make sure to includ all other values. Otherwise they will be dropped
resp = new_record.update(nil,nil,"600",nil)

#Deleting a zone
#A zone can't be deleted until all of it's records have been deleted (Except for 1 NS record and 1 SOA record)
new_zone.get_records.each do |record|
  unless record.type == 'NS' || record.type == 'SOA'
    record.delete
  end
end
new_zone.delete_zone
```

Requirements
------------

Written with Ruby 1.9.2 on an Ubuntu Linux machine. Smoke tested on an Ubuntu Linux machine with Ruby 1.8.7.

Amazon AWS account with Route 53 opted into - See the signup link at [http://aws.amazon.com/route53/](http://aws.amazon.com/route53/)
ruby openssl support
ruby-hmac
hpricot
builder

Support and Bugs
----------------

Bug reports are appreciated and encouraged. Please either file a detailed issue on [Github](https://github.com/pcorliss/ruby_route_53/issues) or send an email to support@50projects.com.

Contact
-------

This ruby interface for Amazon's Route 53 service was created by Philip Corliss (pcorliss@50projects.com) [50projects.com](http://50projects.com). You can find more information on him and 50projects at [http://blog.50projects.com](http://blog.50projects.com)

License
-------

Ruby Route 53 is licensed under the GPL. See the LICENSE file for details.
