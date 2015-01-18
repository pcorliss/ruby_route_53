require 'route53'
require 'vcr'
require 'webmock/rspec'

VCR.configure do |c|
  c.cassette_library_dir = 'spec/fixtures/vcr_cassettes'
  c.hook_into :webmock
end

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus
  config.order = 'random'
  config.mock_with :rspec do |mocks|
    mocks.syntax = :should
  end
end

def credentials(key)
  credentials_file = File.join(ENV['HOME'], '.route53')
  File.exist?(credentials_file) ? YAML.load_file(credentials_file)[key] : ''
end
