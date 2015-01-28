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
require 'cosmos/tools/launcher/launcher_config'
require 'tempfile'

module Cosmos

  describe LauncherConfig do
    describe "initialize" do
      it "checks for a given filename" do
        expect { LauncherConfig.new('blah_file.txt') }.to raise_error
      end

      it "raises on unknown parameters" do
        tf = Tempfile.new('mylauncher.txt')
        tf.puts "UNKNOWN"
        tf.close
        expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
        tf.unlink
      end

      describe 'TITLE' do
        it "parses a single string" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TITLE \"MyLauncher\""
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.title).to eq "MyLauncher"
          tf.unlink
        end

        it "raises with more than 1 parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TITLE My Launcher"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe 'DIVIDER' do
        it "parses without arguments" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "DIVIDER"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to_not raise_error
          tf.unlink
        end

        it "raises with a parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "DIVIDER 1"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe 'NUM_COLUMNS' do
        it "parses a single value" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "NUM_COLUMNS 6"
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.num_columns).to eq 6
          tf.unlink
        end

        it "raises with a string" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "NUM_COLUMNS TWO"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than 1 parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "NUM_COLUMNS 2 3"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe 'LABEL' do
        it "parses a single value" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "LABEL 'HI THERE'"
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][0]).to eq :LABEL
          expect(lc.items[0][1]).to eq "HI THERE"
          expect(lc.items[0][2]).to be_nil
          expect(lc.items[0][3]).to be_nil
          expect(lc.items[0][4]).to be_nil
          tf.unlink
        end

        it "raises with more than 1 parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "LABEL HI THERE"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe 'TOOL_FONT' do
        it "parses the font and size" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TOOL_FONT tahoma 12"
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.tool_font_settings[0]).to eq 'tahoma'
          expect(lc.tool_font_settings[1]).to eq 12
          tf.unlink
        end

        it "raises with only 1 parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TOOL_FONT tahoma"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than 2 parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TOOL_FONT tahoma 12 16"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        # TODO: Is it possible to check for bad fonts?

        it "raises with a bad size" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "TOOL_FONT tahoma arial"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe 'LABEL_FONT' do
        it "parses the font and size" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "LABEL_FONT tahoma 12"
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.label_font_settings[0]).to eq 'tahoma'
          expect(lc.label_font_settings[1]).to eq 12
          tf.unlink
        end

        it "raises with only 1 parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "LABEL_FONT tahoma"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than 2 parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "LABEL_FONT tahoma 12 16"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        # TODO: Is it possible to check for bad fonts?

        it "raises with a bad size" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts "LABEL_FONT tahoma arial"
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "DONT_CAPTURE_IO" do
        it "must follow a TOOL" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts '  DONT_CAPTURE_IO'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink

          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START "MyTool"'
          tf.puts '  DONT_CAPTURE_IO'
          tf.puts '  TOOL "LAUNCH CmdTlmServer"'
          tf.puts 'MULTITOOL_END'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink

          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'TOOL "Server" "LAUNCH CmdTlmServer"'
          tf.puts '  DONT_CAPTURE_IO'
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][3]).to be false
          tf.unlink
        end

        it "raises with a parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'TOOL "Server" "LAUNCH CmdTlmServer"'
          tf.puts '  DONT_CAPTURE_IO true'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "valid within MULTITOOL" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START "MyTool"'
          tf.puts '  TOOL "LAUNCH CmdTlmServer"'
          tf.puts '    DONT_CAPTURE_IO'
          tf.puts 'MULTITOOL_END'
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][2][0][2]).to be false
          tf.unlink
        end
      end

      describe "TOOL" do
        it "parses name and LAUNCH shell command" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'TOOL "Server" "LAUNCH CmdTlmServer --system system.txt -x 0 -y 0"'
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][0]).to eq :TOOL
          expect(lc.items[0][1]).to eq 'Server'
          if Kernel.is_mac? and File.exist?(File.join(USERPATH, 'tools', 'mac'))
            expect(lc.items[0][2]).to eq 'open tools/mac/CmdTlmServer.app --args --system system.txt -x 0 -y 0'
          else
            expect(lc.items[0][2]).to eq 'RUBYW tools/CmdTlmServer --system system.txt -x 0 -y 0'
          end
          expect(lc.items[0][3]).to be true
          expect(lc.items[0][4]).to be_nil
          expect(lc.items[0][5]).to be_nil
          tf.unlink
        end

        it "parses name and LAUNCH_TERMINAL shell command" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'TOOL "Example" "LAUNCH_TERMINAL Example"'
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][0]).to eq :TOOL
          expect(lc.items[0][1]).to eq 'Example'
          if Kernel.is_mac?
            expect(lc.items[0][2]).to eq "osascript -e 'tell application \"Terminal\" to do script \"cd #{File.expand_path(USERPATH)} && ruby tools/Example \"' -e 'return'"
          elsif Kernel.is_windows?
            expect(lc.items[0][2]).to eq "start ruby tools/Example"
          else
            expect(lc.items[0][2]).to eq "gnome-terminal -e \"ruby tools/Example"
          end
          expect(lc.items[0][3]).to be true
          expect(lc.items[0][4]).to be_nil
          expect(lc.items[0][5]).to be_nil
          tf.unlink
        end

        it "parses name and random shell command" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'TOOL "List" "ls -la"'
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][0]).to eq :TOOL
          expect(lc.items[0][1]).to eq 'List'
          expect(lc.items[0][2]).to eq 'ls -la'
          tf.unlink
        end

        it "parses icon and parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'TOOL "Server" "LAUNCH CmdTlmServer --system system.txt -x 0 -y 0" "cts.png" --config server.txt --width 500 --height 500'
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][4]).to eq 'cts.png'
          expect(lc.items[0][5].join(' ')).to eq '--config server.txt --width 500 --height 500'
          tf.unlink
        end

        it "raises with less than 2 parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'TOOL "Server"'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "DELAY" do
        it "only valid within MULTITOOL" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts '  DELAY'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink

          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START "MyTool" icon.png'
          tf.puts '  DELAY 1'
          tf.puts '  TOOL "LAUNCH CmdTlmServer"'
          tf.puts 'MULTITOOL_END'
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][2][0][0]).to eq :DELAY
          expect(lc.items[0][2][0][1]).to eq 1
          tf.unlink
        end

        it "raises without a parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START "MyTool" icon.png'
          tf.puts '  DELAY'
          tf.puts '  TOOL "LAUNCH CmdTlmServer"'
          tf.puts 'MULTITOOL_END'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than 1 parameter" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START "MyTool" icon.png'
          tf.puts '  DELAY 1 2'
          tf.puts '  TOOL "LAUNCH CmdTlmServer"'
          tf.puts 'MULTITOOL_END'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end

      describe "MULTITOOL" do
        it "parses name and icon" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START "MyTool" icon.png'
          tf.puts '  TOOL "LAUNCH CmdTlmServer"'
          tf.puts 'MULTITOOL_END'
          tf.close

          lc = LauncherConfig.new(tf.path)
          expect(lc.items[0][0]).to eq :MULTITOOL
          expect(lc.items[0][1]).to eq 'MyTool'
          expect(lc.items[0][2]).to_not be_empty
          expect(lc.items[0][3]).to be true
          expect(lc.items[0][4]).to eq 'icon.png'
          expect(lc.items[0][5]).to be_nil
          tf.unlink
        end

        it "raises with no parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START'
          tf.puts '  TOOL "LAUNCH CmdTlmServer"'
          tf.puts 'MULTITOOL_END'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises with more than two parameters" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START Launch icon.png more'
          tf.puts '  TOOL "LAUNCH CmdTlmServer"'
          tf.puts 'MULTITOOL_END'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end

        it "raises if no tools are defined" do
          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START Launch'
          tf.puts 'MULTITOOL_END'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink

          tf = Tempfile.new('mylauncher.txt')
          tf.puts 'MULTITOOL_START Launch'
          tf.puts '  DELAY 1'
          tf.puts 'MULTITOOL_END'
          tf.close

          expect { LauncherConfig.new(tf.path) }.to raise_error(Cosmos::ConfigParser::Error)
          tf.unlink
        end
      end
    end

#  DONT_CAPTURE_IO
#MULTITOOL_START "COSMOS"
#  TOOL "LAUNCH CmdTlmServer -x 827 -y 2 -w 756 -t 475 -c cmd_tlm_server.txt"
#  DELAY 5
#  TOOL "LAUNCH TlmViewer -x 827 -y 517 -w 424 -t 111"
#    DONT_CAPTURE_IO
#MULTITOOL_END
#DIVIDER
#LABEL "This is a test"
#DOC

  end
end

