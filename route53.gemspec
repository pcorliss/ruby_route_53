# -*- encoding: utf-8 -*-
require File.expand_path("../lib/route53/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "route53"
  s.version     = Route53::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = "Philip Corliss"
  s.email       = 'pcorlis@50projects.com'
  s.homepage    = 'http://github.com/pcorliss/ruby_route_53'
  s.summary     = "Library for Amazon's Route 53 service"
  s.description = "Provides CRUD and list operations for records and zones as part of Amazon's Route 53 service."

  s.required_rubygems_version = ">= 1.3.5"

  s.add_dependency "ruby-hmac"
  s.add_dependency "nokogiri"
  s.add_dependency "builder"

  s.add_development_dependency "rspec", "~> 3.0"
  s.add_development_dependency "vcr"
  s.add_development_dependency "webmock", '~> 2.3.2'
  # addressable 2.5 requires public_suffix 2.0.4 which doesn't support older versions of ruby
  s.add_development_dependency "addressable", '~> 2.4.0'
  s.add_development_dependency "pry"
  s.add_development_dependency "wirble"
  s.add_development_dependency "rake"

  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
