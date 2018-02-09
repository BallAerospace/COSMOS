# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_logging'

describe DartLogging do
  describe "logging" do
    it "starts a log and captures stdout" do
      logger = DartLogging.new('dart_test')
      sleep 0.1
      test_string = "This is a test"
      puts test_string # This should go in the log
      logger.stop

      Dir["#{Cosmos::System.paths['DART_LOGS']}/*"].each do |file|
        expect(file).to match(/dart_test/)
        data = File.read(file)
        expect(File.read(file)).to include(test_string)
      end
    end
  end
end
