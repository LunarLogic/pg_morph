require 'rake/testtask'
require 'rspec/core/rake_task'
require_relative './spec/dummy/config/application.rb'

task :default => :spec
RSpec::Core::RakeTask.new

Dummy::Application.load_tasks

desc 'test pg_morph'
Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = true
end
