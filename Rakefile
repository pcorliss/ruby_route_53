require 'rake/testtask'
Rake::TestTask.new(:default) do |test|
  test.pattern = 'test/*_test.rb'
  test.verbose = true
end

require 'rcov/rcovtask'
Rcov::RcovTask.new do |test|
  test.libs << 'lib'
  test.pattern = 'test/*_test.rb'
  test.verbose = true
  test.rcov_opts << "--exclude gems/*"
end