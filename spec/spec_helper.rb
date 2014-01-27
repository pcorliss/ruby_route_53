require 'route53'
require 'vcr'
require 'webmock/rspec'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
end

RSpec.configure do |config|
  config.treat_symbols_as_metadata_keys_with_true_values = true
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
end

def credentials(key)
  YAML.load_file(File.join(ENV['HOME'], '.route53'))[key]
end
