module Route53
  class DNSRecord
    attr_reader :name
    attr_reader :type
    attr_reader :ttl
    attr_reader :values
    attr_reader :weight
    attr_reader :ident
    attr_reader :zone_apex
    attr_reader :health_id

    def initialize(name,type,ttl,values,zone,zone_apex=nil,weight=nil,ident=nil, evaluate_target_health=false, health_id=nil)
      @name = name
      unless @name.end_with?(".")
        @name += "."
      end
      @type = type.upcase
      @ttl = ttl
      @values = values
      @zone = zone
      @zone_apex = zone_apex
      @weight = weight
      @ident = ident
      @evaluate_target_health = evaluate_target_health
      @health_id = health_id
    end

    def gen_change_xml(xml,action)
      xml.Change { |change|
        change.Action(action.upcase)
        change.ResourceRecordSet { |record|
          record.Name(@name)
          record.Type(@type)
          record.SetIdentifier(@ident) if @ident
          record.Weight(@weight) if @weight
          record.TTL(@ttl) unless @zone_apex
          record.HealthCheckId(@health_id) if @health_id
          if @zone_apex
            record.AliasTarget { |targets|
              targets.HostedZoneId(@zone_apex)
              targets.DNSName(@values.first)
              targets.EvaluateTargetHealth(@evaluate_target_health)
            }
          else
            record.ResourceRecords { |resources|
              @values.each { |val|
                resources.ResourceRecord { |record|
                  record.Value(val)
                }
              }
            }
          end
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
    def update(name,type,ttl,values,comment=nil, zone_apex = nil)
      prev = self.clone
      @name = name unless name.nil?
      @type = type unless type.nil?
      @ttl = ttl unless ttl.nil?
      @values = values unless values.nil?
      @zone_apex = zone_apex unless zone_apex.nil?
      @zone.perform_actions([
          {:action => "DELETE", :record => prev},
          {:action => "CREATE", :record => self},
          ],comment)
    end

    #Returns the raw array so the developer can update large batches manually
    #Need to modify to a param hash
    def update_dirty(name,type,ttl,values,zone_apex = nil)
      prev = self.clone
      @name = name unless name.nil?
      @type = type unless type.nil?
      @ttl = ttl unless ttl.nil?
      @values = values unless values.nil?
      @zone_apex = zone_apex unless zone_apex.nil?
      return [{:action => "DELETE", :record => prev},
      {:action => "CREATE", :record => self}]
    end

    def to_s
      if @weight
        "#{@name} #{@type} #{@ttl} '#{@ident}' #{@weight} #{@values.join(",")}"
      elsif @zone_apex
        "#{@name} #{@type} #{@zone_apex} #{@values.join(",")}"
      else
        "#{@name} #{@type} #{@ttl} #{@values.join(",")}"
      end
    end
  end
end
