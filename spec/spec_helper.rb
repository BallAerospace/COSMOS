# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# NOTE: You MUST require simplecov before anything else!
unless ENV['COSMOS_NO_SIMPLECOV']
  require 'simplecov'
  SimpleCov.start do
    merge_timeout 7200 # merge the last two hours of results
    add_filter '/spec/'
    add_filter '/autohotkey/'

    add_group 'Core' do |src|
      !src.filename.include?('gui') && !src.filename.include?('tools')
    end
    add_group 'GUI', 'gui'
    add_group 'Tools', 'tools'
  end
  SimpleCov.at_exit do
    Encoding.default_external = Encoding::UTF_8
    Encoding.default_internal = nil
    SimpleCov.result.format!
  end
else
  require "codeclimate-test-reporter"
  CodeClimate::TestReporter.start
end
require 'rspec'
require 'ruby-prof'
require 'cosmos'
require 'cosmos/utilities/logger'

# Set the user path to our COSMOS configuration in the spec directory
Cosmos.disable_warnings do
  Cosmos::USERPATH = File.join(File.expand_path(File.dirname(__FILE__)), 'install')
end

DEFAULT_USERPATH = Cosmos::USERPATH

$system_exit_count = 0
# Overload exit so we know when it is called

alias old_exit exit
def exit(*args)
  $system_exit_count += 1
end

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    # Explicitly enable the should and expect syntax
    c.syntax = [:should, :expect]
  end

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
  end

  #config.after(:each) {}
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
  c.around(:each) do |example|
    if ENV.key?("PROFILE")
      klass = example.metadata[:example_group][:example_group][:description_args][0].to_s.gsub(/::/,'')
      method = example.metadata[:description_args][0].to_s.gsub!(/ /,'_')
      RubyProf.start
      100.times do
        example.run
      end
      result = RubyProf.stop
      result.eliminate_methods!([/RSpec/, /BasicObject/])
      printer = RubyProf::GraphHtmlPrinter.new(result)
      dir = "./profile/#{klass}"
      FileUtils.mkdir_p(dir)
      printer.print(File.open("#{dir}/#{method}.html", 'w+'), :min_percent => 2)
    else
      example.run
    end
  end
end

