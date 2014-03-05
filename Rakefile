require 'special_delivery/gem_tasks'
require 'rspec/core/rake_task'

desc 'Default: run specs.'
task :default => :spec

desc "Run specs"
RSpec::Core::RakeTask.new('spec') do |spec|
  spec.pattern = "./spec/**/*_spec.rb"
end

require 'rdoc/task'
RDoc::Task.new do |rdoc|
  require 'logstasher/version'
  version = LogStasher::VERSION

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "logstasher #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end
