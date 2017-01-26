# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# Redefine Object.load so simplecov doesn't overwrite the results after
# re-loading a file during test.
def load(file, wrap = false)
  SimpleCov.start do
    command_name "#{command_name}1"
  end
  Kernel.load(file, wrap)
end

# NOTE: You MUST require simplecov before anything else!
unless ENV['COSMOS_NO_SIMPLECOV']
  require 'simplecov'
  require 'coveralls'
  Coveralls.wear!
  SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
    SimpleCov::Formatter::HTMLFormatter,
    Coveralls::SimpleCov::Formatter
  ])
  SimpleCov.start do
    merge_timeout 12 * 60 * 60 # merge the last 12 hours of results
    add_filter '/spec/'
    add_filter '/autohotkey/'

    add_group 'Core' do |src|
      !src.filename.include?('gui') && !src.filename.include?('tools')
    end
    add_group 'GUI', 'gui'
    add_group 'Tools', 'tools'
    root = File.dirname(__FILE__)
  end
  SimpleCov.at_exit do
    Encoding.default_external = Encoding::UTF_8
    Encoding.default_internal = nil
    SimpleCov.result.format!
  end
end
require 'rspec'
require 'ruby-prof'
require 'benchmark/ips'

# Set the user path to our COSMOS configuration in the spec directory
ENV['COSMOS_USERPATH'] = File.join(File.dirname(File.expand_path(__FILE__)), 'install')

require 'cosmos'
require 'cosmos/utilities/logger'

DEFAULT_USERPATH = Cosmos::USERPATH

$system_exit_count = 0
# Overload exit so we know when it is called

alias old_exit exit
def exit(*args)
  $system_exit_count += 1
end

RSpec.configure do |config|
  # Store standard output global and CONSTANT since we will mess with them
  config.before(:all) do
    $saved_stdout_global = $stdout
    $saved_stdout_const  = Object.const_get(:STDOUT)
  end

  config.after(:all) {
    def Object.exit(*args)
      old_exit(*args)
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
    # Kill any leftover threads
    if Thread.list.length > 1
      Thread.list.each do |t|
        t.kill if t != Thread.current
      end
      sleep(0.2)
    end
  end

  config.after(:each) do
    # Make sure we didn't leave any lingering threads
    expect(Thread.list.length).to eql(1), "At end of test expect 1 remaining thread but found #{Thread.list.length}.\nEnsure you kill all spawned threads before the test finishes."
  end
end

# Clean up the spec configuration directory
def clean_config
  %w(outputs/logs outputs/saved_config outputs/tmp outputs/tables outputs/handbooks).each do |dir|
    FileUtils.rm_rf(Dir.glob(File.join(Cosmos::USERPATH, dir, '*')))
  end
end

# Set the logger to output everthing and capture it all in a StringIO object
# which is yielded back to the block. Then restore everything.
def capture_io
  # Set the logger level to DEBUG so we see all output
  Cosmos::Logger.instance.level = Logger::DEBUG
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

  # Restore the logger to FATAL to prevent all kinds of output
  Cosmos::Logger.level = Logger::FATAL
  # Restore the STDOUT constant
  Cosmos.disable_warnings do
    Object.const_set(:STDOUT, saved_stdout)
  end
  # Restore the $stdout global to be STDOUT
  $stdout = STDOUT
end

RSpec.configure do |c|
  if ENV.key?("PROFILE")
    c.before(:suite) do
      RubyProf.start
    end
    c.after(:suite) do |example|
      result = RubyProf.stop
      ignore = [/BasicObject/]
      # Get all the RSpec constants so we can ignore them
      RSpec.constants.each do |constant|
        if Object.const_get("RSpec::#{constant}").respond_to? :constants
          Object.const_get("RSpec::#{constant}").constants.each {|sub| ignore << Regexp.new("RSpec::#{constant}::#{sub}") }
        else
          ignore << Regexp.new("RSpec::#{constant}")
        end
      end
      # But don't ignore RSpec::Core::Runner because it's the root.
      # Ignoring this causes "can't eliminate root method (RuntimeError)"
      ignore.delete(Regexp.new("RSpec::Core::Runner"))

      result.eliminate_methods!(ignore)
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

