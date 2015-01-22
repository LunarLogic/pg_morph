require 'rake/testtask'
require 'rspec/core/rake_task'

task :default => :spec
RSpec::Core::RakeTask.new

desc 'test pg_morph'
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end
