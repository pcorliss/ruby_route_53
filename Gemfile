source 'https://rubygems.org'

gemspec

gem 'nokogiri', '~> 1.5.10' if RUBY_VERSION.start_with? '1.8'
gem 'nokogiri', '~> 1.6.0' if RUBY_VERSION.start_with? '2.0'
gem 'nokogiri', '~> 1.6.0' if RUBY_VERSION.start_with? '1.9'

group :development do
  gem 'rake', '< 12.0' if RUBY_VERSION.start_with? '1.9'
  gem 'rake', '< 11.0' if RUBY_VERSION.start_with? '1.8'
  gem 'vcr', '< 3' if RUBY_VERSION.start_with? '1.8'
end
