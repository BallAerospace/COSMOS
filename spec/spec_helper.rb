# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

# Redefine Object.load so simplecov doesn't overwrite the results after
# re-loading a file during test.
def load(file, wrap = false)
  if defined? SimpleCov
    SimpleCov.start do
      command_name "#{command_name}1"
    end
  end
  Kernel.load(file, wrap)
end

# NOTE: You MUST require simplecov before anything else!
if !ENV['COSMOS_NO_SIMPLECOV']
  require 'simplecov'
  if ENV['TRAVIS'] # Only if we're on Travis do we use codecov
    require 'codecov'
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Codecov,
    ])
  end
  SimpleCov.start do
    merge_timeout 12 * 60 * 60 # merge the last 12 hours of results
    add_filter '/spec/'
    add_filter '/autohotkey/'
    root = File.dirname(__FILE__)
    root.to_s
  end
  SimpleCov.at_exit do
    Cosmos.disable_warnings do
      Encoding.default_external = Encoding::UTF_8
      Encoding.default_internal = nil
    end
    SimpleCov.result.format!
  end
end
require 'rspec'
require 'ruby-prof' if RUBY_ENGINE == 'ruby'
require 'benchmark/ips'

# Set the user path to our COSMOS configuration in the spec directory
ENV['COSMOS_USERPATH'] = File.join(File.dirname(File.expand_path(__FILE__)), 'install')
# Disable Redis and Fluentd in the Logger
ENV['NO_STORE'] = 'true'
ENV['NO_FLUENTD'] = 'true'
# TODO: This is a hack until we figure out COSMOS_USERPATH
module Cosmos
  USERPATH = ENV['COSMOS_USERPATH']
end

require 'cosmos'
require 'cosmos/utilities/logger'

DEFAULT_USERPATH = Cosmos::USERPATH

$system_exit_count = 0
# Overload exit so we know when it is called

alias old_exit exit
def exit(*args)
  $system_exit_count += 1
end

$cosmos_scope = 'DEFAULT'

require 'mock_redis'
require 'cosmos/utilities/store'
require 'cosmos/models/plugin_model'

def configure_store
  redis = MockRedis.new
  allow(Redis).to receive(:new).and_return(redis)
  # allow(ConnectionPool).to receive(:new).and_return(redis)
  Cosmos::Store.class_variable_set(:@@instance, nil)

  plugin = File.join(__dir__, 'install', 'cosmos-demo-1.0.0.gem')
  allow(Cosmos::GemModel).to receive(:put)
  allow(Cosmos::GemModel).to receive(:get).and_return(plugin)
  s3 = instance_double("Aws::S3::Client").as_null_object
  allow(Aws::S3::Client).to receive(:new).and_return(s3)

  plugin_hash = Cosmos::PluginModel.install_phase1(plugin, scope: $cosmos_scope)
  Cosmos::PluginModel.install_phase2(plugin_hash['name'], plugin_hash['variables'], scope: $cosmos_scope)
  redis
end

RSpec.configure do |config|
  # Enforce the new expect() syntax instead of the old should syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Store standard output global and CONSTANT since we will mess with them
  config.before(:all) do
    $saved_stdout_global = $stdout
    $saved_stdout_const  = Object.const_get(:STDOUT)
  end

  config.after(:all) {
    clean_config()
    Cosmos.disable_warnings do
      def Object.exit(*args)
        old_exit(*args)
      end
    end
  }

  # Before each test make sure $stdout and STDOUT are set. They might be messed
  # up if a spec fails in the middle of capture_io and we don't have a chance
  # to return and reset them.
  config.before(:each) do
    $stdout = $saved_stdout_global if $stdout != $saved_stdout_global
    Cosmos.disable_warnings do
      Object.const_set(:STDOUT, $saved_stdout_const)
    end
    kill_leftover_threads()
  end

  config.after(:each) do
    # Make sure we didn't leave any lingering threads
    threads = running_threads()
    thread_count = threads.size()
    running_threads_str = threads.join("\n")

    expect(thread_count).to eql(1), "At end of test expect 1 remaining thread but found #{thread_count}.\nEnsure you kill all spawned threads before the test finishes.\nThreads:\n#{running_threads_str}"
  end
end

# Clean up the spec configuration directory
def clean_config
  %w(outputs/logs outputs/saved_config outputs/tmp outputs/tables outputs/handbooks procedures).each do |dir|
    FileUtils.rm_rf(Dir.glob(File.join(Cosmos::USERPATH, dir, '*')))
  end
end

# Set the logger to output everthing and capture it all in a StringIO object
# which is yielded back to the block. Then restore everything.
def capture_io
  # Set the logger level to DEBUG so we see all output
  Cosmos::Logger.instance.level = Logger::DEBUG
  Cosmos::Logger.stdout = true
  # Create a StringIO object to capture the output
  stdout = StringIO.new('', 'r+')
  $stdout = stdout
  saved_stdout = nil
  Cosmos.disable_warnings do
    # Save the old STDOUT constant value
    saved_stdout = Object.const_get(:STDOUT)
    # Set STDOUT to our StringIO object
    Object.const_set(:STDOUT, $stdout)
  end

  # Yield back the StringIO so they can match against it
  yield stdout

  Cosmos::Logger.stdout = false
  # Restore the logger to FATAL to prevent all kinds of output
  Cosmos::Logger.level = Logger::FATAL
  # Restore the STDOUT constant
  Cosmos.disable_warnings do
    Object.const_set(:STDOUT, saved_stdout)
  end
  # Restore the $stdout global to be STDOUT
  $stdout = STDOUT
end

# Get a list of running threads, ignoring jruby system threads if necessary.
def running_threads
  threads = []
  Thread.list.each do |t|
    if RUBY_ENGINE == 'jruby'
      thread_name = JRuby.reference(t).native_thread.get_name
      threads << t.inspect unless thread_name == "Finalizer" or thread_name.include?("JRubyWorker")
    else
      threads << t.inspect
    end
  end
  return threads
end

# Kill threads that are not "main", ignoring jruby system threads if necessary.
def kill_leftover_threads
  if RUBY_ENGINE == 'jruby'
    if Thread.list.length > 2
      Thread.list.each do |t|
        thread_name = JRuby.reference(t).native_thread.get_name
        t.kill if t != Thread.current and thread_name != "Finalizer" and !thread_name.include?("JRubyWorker")
      end
      sleep(0.2)
    end
  else
    if Thread.list.length > 1
      Thread.list.each do |t|
        t.kill if t != Thread.current
      end
      sleep(0.2)
    end
  end
end

RSpec.configure do |c|
  if ENV.key?("PROFILE")
    c.before(:suite) do
      RubyProf.start
    end
    c.after(:suite) do |example|
      result = RubyProf.stop
      result.exclude_common_methods!
      printer = RubyProf::GraphHtmlPrinter.new(result)
      printer.print(File.open("profile.html", 'w+'), :min_percent => 1)
    end
    c.around(:each) do |example|
      # Run each test 100 times to prevent startup issues from dominating
      100.times do
        example.run
      end
    end
  end
  if ENV.key?("BENCHMARK")
    c.around(:each) do |example|
      Benchmark.ips do |x|
        x.report(example.metadata[:full_description]) do
          example.run
        end
      end
    end
  end
  if ENV.key?("STRESS")
    c.around(:each) do |example|
      begin
        GC.stress = true
        example.run
      ensure
        GC.stress = false
      end
    end
  end
# This code causes a new profile file to be created for each test case which is excessive and hard to read
#  c.around(:each) do |example|
#    if ENV.key?("PROFILE")
#      klass = example.metadata[:example_group][:example_group][:description_args][0].to_s.gsub(/::/,'')
#      method = example.metadata[:description_args][0].to_s.gsub!(/ /,'_')
#      RubyProf.start
#      100.times do
#        example.run
#      end
#      result = RubyProf.stop
#      result.eliminate_methods!([/RSpec/, /BasicObject/])
#      printer = RubyProf::GraphHtmlPrinter.new(result)
#      dir = "./profile/#{klass}"
#      FileUtils.mkdir_p(dir)
#      printer.print(File.open("#{dir}/#{method}.html", 'w+'), :min_percent => 2)
#    else
#      example.run
#    end
#  end
end
