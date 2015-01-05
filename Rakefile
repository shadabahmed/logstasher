require "bundler/gem_tasks"
require 'rspec/core/rake_task'

# Add default task. When you type just rake command this would run. Travis CI runs this. Making this run spec
desc 'Default: run specs.'
task :default => :spec

# Defining spec task for running spec
desc "Run specs"
RSpec::Core::RakeTask.new('spec') do |spec|
  # Pattern filr for spec files to run. This is default btw.
  spec.pattern = "./spec/**/*_spec.rb"
end

# Run the rdoc task to generate rdocs for this gem
require 'rdoc/task'
RDoc::Task.new do |rdoc|
  require File.expand_path("../lib/logstasher/version", __FILE__)
  version = LogStasher::VERSION

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "logstasher #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

# Code coverage tasks. Different for Ruby 1.8 vs 1.9
if RUBY_VERSION =~ /^1\.8/
  # Ruby 1.8 uses rcov for code coverage
  RSpec::Core::RakeTask.new(:coverage) do |spec|
    spec.pattern = 'spec/**/*_spec.rb'
    spec.rcov = true
    spec.rcov_opts = %w{--exclude pkg\/,spec\/,features\/}
  end
else
  # Ruby 1.9+ using simplecov. Note: Simplecov config defined in spec_helper
  desc "Code coverage detail"
  task :coverage do
    ENV['COVERAGE'] = "true"
    Rake::Task['spec'].execute
  end
end

task :console do
  require 'irb'
  require 'irb/completion'
  require 'logstasher'
  ARGV.clear
  IRB.start
end
