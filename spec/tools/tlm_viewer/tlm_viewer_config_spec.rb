# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/tools/tlm_viewer/tlm_viewer_config'
require 'tempfile'
require 'ostruct'

module Cosmos

  describe TlmViewerConfig do
    before(:all) do
      # Allow the require widget to work
      Cosmos.add_to_search_path(File.join(Cosmos::USERPATH,'../../lib/cosmos/tools/tlm_viewer/widgets'))
    end

    describe "initialize" do
      it "checks for a given filename" do
        expect { TlmViewerConfig.new('blah_file.txt') }.to raise_error("Configuration file blah_file.txt does not exist.")
      end

      it "raises on unknown parameters" do
        tf = Tempfile.new('mylauncher.txt')
        tf.puts "UNKNOWN"
        tf.close
        expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
        tf.unlink
      end

      describe 'NEW_COLUMN' do
        it "creates a new column in the configuration" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "NEW_COLUMN"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.columns.length).to eq 2 # Starts with 1 by default
          tf.unlink

          tf = Tempfile.new('mylauncher.txt')
          tf.puts "NEW_COLUMN"
          tf.puts "NEW_COLUMN"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.columns.length).to eq 3
          tf.unlink
        end

        it "raises with parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "NEW_COLUMN 2"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe 'AUTO_TARGETS' do
        it "automatically parses all target screen directories" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "AUTO_TARGETS"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.screen_infos.include?("INST HS")).to be true
          expect(tvc.screen_infos.include?("SYSTEM STATUS")).to be true
          tf.unlink
        end

        it "raises with parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "AUTO_TARGETS TRUE"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe 'AUTO_TARGET' do
        it "automatically parses the target screen directories" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "AUTO_TARGET INST"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.screen_infos.include?("INST HS")).to be true
          expect(tvc.screen_infos.include?("SYSTEM STATUS")).to be false
          tf.unlink
        end

        it "raises with parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "AUTO_TARGET"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than one parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "AUTO_TARGET INST TRUE"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with an unknown target" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "AUTO_TARGET BLAH"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe 'TARGET' do
        it "raises with no parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TARGET"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than one parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TARGET INST TRUE"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with an unknown target" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TARGET BLAH"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "SCREEN" do
        it "parses a specified target, screen and position" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TARGET INST"
          tf.puts "SCREEN hs.txt 100 200"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.screen_infos.include?("INST HS")).to be true
          expect(tvc.screen_infos["INST HS"].x_pos).to eql 100
          expect(tvc.screen_infos["INST HS"].y_pos).to eql 200
          tf.unlink
        end

        it "raises unless preceeded by TARGET" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "SCREEN hs.txt"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with no parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TARGET INST"
          tf.puts "SCREEN"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than 3 parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TARGET INST"
          tf.puts "SCREEN hs.txt 100 200 300"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "SHOW_ON_STARTUP" do
        it "indicates a screen should be shown when TlmViewer launches" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TARGET INST"
          tf.puts "SCREEN hs.txt 100 200"
          tf.puts "SHOW_ON_STARTUP"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.screen_infos.include?("INST HS")).to be true
          expect(tvc.screen_infos["INST HS"].show_on_startup).to be true
          tf.unlink
        end

        it "raises unless preceeded by SCREEN" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "SHOW_ON_STARTUP"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TARGET INST"
          tf.puts "SCREEN hs.txt"
          tf.puts "SHOW_ON_STARTUP TRUE"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "ADD_SHOW_ON_STARTUP" do
        it "indicates a screen should be shown when TlmViewer launches" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "AUTO_TARGETS"
          tf.puts "ADD_SHOW_ON_STARTUP INST HS 100 200"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.screen_infos.include?("INST HS")).to be true
          expect(tvc.screen_infos["INST HS"].show_on_startup).to be true
          tf.unlink
        end

        it "raises if the screen wasn't previously defined" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "ADD_SHOW_ON_STARTUP INST HS 100 200"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with less than 2 parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "ADD_SHOW_ON_STARTUP INST"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than 4 parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "ADD_SHOW_ON_STARTUP INST hs.txt 100 200 300"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "GROUP" do
        it "defines a new group in TlmViewer" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "GROUP Tester"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.columns[0].keys.include?("Tester")).to be true
          tf.unlink
        end

        it "raises with no parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "GROUP"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than 1 parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "GROUP Tester Tester"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "GROUP_SCREEN" do
        it "defines a screen in a group" do
          tf = Tempfile.new('mylauncher.txt')
          #tf.puts "AUTO_TARGETS"
          tf.puts "TARGET INST"
          tf.puts "SCREEN hs.txt"
          tf.puts "GROUP Tester"
          tf.puts "GROUP_SCREEN INST HS 100 200"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          expect(tvc.columns[0]["Tester"]["INST_HS"].group).to eql "Tester"
          tf.unlink
        end

        it "raises with less than 2 parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "GROUP_SCREEN INST"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than 4 parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "GROUP_SCREEN INST HS 100 200 300"
          tf.close

          expect { TlmViewerConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "to_save" do
        it "saves AUTO_TARGETS as TARGET/SCREEN" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "AUTO_TARGETS"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          config_file = File.join(Cosmos::USERPATH, "test_config.txt")
          tvc.save(config_file)
          tf.unlink

          config = File.read(config_file)
          expect(config).to match(/TARGET "INST"/)
          expect(config).to match(/SCREEN "hs.txt"/)
          expect(config).to match(/TARGET "SYSTEM"/)
          expect(config).to match(/SCREEN "status.txt"/)
          FileUtils.rm_f config_file
        end

        it "saves the configuration" do
          tf = Tempfile.new('mylauncher.txt')
          inst_hs = "TARGET \"INST\"\n"\
                    "  SCREEN \"hs.txt\"\n"\
                    "    SHOW_ON_STARTUP\n"
          tf.puts inst_hs
          tf.puts "NEW_COLUMN"
          test_group = "GROUP \"Test\"\n"\
                       "  GROUP_SCREEN SYSTEM STATUS 100 200\n"\
                       "  GROUP_SCREEN INST HS\n"\
                       "    SHOW_ON_STARTUP\n"
          tf.puts test_group
          another_group = "GROUP \"2Another\"\n"\
                          "  GROUP_SCREEN INST HS\n"\
                          "  GROUP_SCREEN SYSTEM STATUS 300 400\n"\
                          "    SHOW_ON_STARTUP\n"
          tf.puts another_group
          tf.puts "NEW_COLUMN"
          tf.puts "TARGET SYSTEM"
          tf.puts "  SCREEN status.txt"
          tf.puts "ADD_SHOW_ON_STARTUP SYSTEM STATUS 500 600"
          tf.close

          tvc = TlmViewerConfig.new(tf.path)
          config_file = File.join(Cosmos::USERPATH, "test_config.txt")
          tvc.save(config_file)
          tf.unlink

          config = File.read(config_file)
          expect(config).to include(inst_hs)
          expect(config).to include(test_group)
          expect(config).to include(test_group)
          expect(config).to include("TARGET \"SYSTEM\"\n  SCREEN \"status.txt\" 500 600\n    SHOW_ON_STARTUP")
          expect(config.scan(/NEW_COLUMN/).count).to eql 2
          FileUtils.rm_f config_file
        end
      end

    end
  end
end

