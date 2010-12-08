# -*- encoding: utf-8 -*-
require File.expand_path("../lib/route53/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = "route53"
  s.version     = Route53::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = "Philip Corliss"
  s.email       = 'pcorlis@50projects.com'
  s.homepage    = 'http://github.com/pcorliss/ruby_route_53'
  s.summary     = "A gem summary"
  s.description = "A gem description"

  s.required_rubygems_version = ">= 1.3.6"
  s.rubyforge_project         = "route53"

  s.add_development_dependency "bundler", ">= 1.0.0"
  s.add_development_dependency "ruby-hmac"
  s.add_development_dependency "hpricot"
  s.add_development_dependency "builder"
  
  s.files        = `git ls-files`.split("\n")
  s.executables  = `git ls-files`.split("\n").map{|f| f =~ /^bin\/(.*)/ ? $1 : nil}.compact
  s.require_path = 'lib'
end
