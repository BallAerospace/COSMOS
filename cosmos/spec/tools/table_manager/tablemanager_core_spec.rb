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
require 'cosmos/tools/table_manager/table_manager_core'

module Cosmos

  describe TableManagerCore do
    let(:core) { TableManagerCore.new }

    describe "process_definition" do
      it "complains if the definition filename does not exist" do
        expect { core.process_definition('path') }.to raise_error("Configuration file path does not exist.")
      end

      it "processes the table definition" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.close
        core.process_definition(tf.path)
        tf.unlink
        expect(core.config).to_not be_nil
      end
    end

    describe "generate_json" do
      it "generates json from the ONE_DIMENSIONAL table definition" do
        bin = Tempfile.new('table.bin')
        bin.write("\x00\x01")
        bin.close
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE "PPS Selection" BIG_ENDIAN ONE_DIMENSIONAL "Payload Clock Control Pulse Per Second Selection Table"'
        tf.puts '  APPEND_PARAMETER "Primary PPS" 8 UINT 0 1 1'
        tf.puts '    STATE CHECKED 1'
        tf.puts '    STATE UNCHECKED 0'
        tf.puts '  APPEND_PARAMETER "Redundant PPS" 8 UINT 0 1 1'
        tf.puts '    UNEDITABLE'
        tf.puts '    STATE UNCHECKED 0'
        tf.puts '    STATE CHECKED 1'
        tf.close
        json = core.generate_json(bin.path, tf.path)
        bin.unlink
        tf.unlink
        result = JSON.parse(json)
        pp result
        expect(result).to be_a Hash
        expect(result.keys).to eql ['PPS SELECTION']
        expect(result['PPS SELECTION']["num_rows"]).to eql 2
        expect(result['PPS SELECTION']["num_columns"]).to eql 1
        expect(result['PPS SELECTION']["rows"][0]['name']).to eql 'PRIMARY PPS'
        expect(result['PPS SELECTION']["rows"][0]['value']).to eql 'UNCHECKED'
        expect(result['PPS SELECTION']["rows"][1]['name']).to eql 'REDUNDANT PPS'
        expect(result['PPS SELECTION']["rows"][1]['value']).to eql 'CHECKED'
      end

      it "generates json from the TWO_DIMENSIONAL table definition" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE "TLM Monitoring" BIG_ENDIAN TWO_DIMENSIONAL 10 "Telemetry Monitoring Table"'
        tf.puts '  APPEND_PARAMETER "Threshold" 32 UINT MIN MAX 0 "Telemetry item threshold at which point persistance is incremented"'
        tf.puts '  APPEND_PARAMETER "Offset" 32 UINT MIN MAX 0 "Offset into the telemetry packet to monitor"'
        tf.puts '  APPEND_PARAMETER "Data Size" 32 UINT 0 3 0 "Amount of data to monitor (bytes)"'
        tf.puts '    STATE BITS 0'
        tf.puts '    STATE BYTE 1'
        tf.puts '    STATE WORD 2'
        tf.puts '    STATE LONGWORD 3'
        tf.puts '  APPEND_PARAMETER "Bit Mask" 32 UINT MIN MAX 0 "Bit Mask to apply to the Data Size before the value is compared ot the Threshold"'
        tf.puts '  APPEND_PARAMETER "Persistence" 32 UINT MIN MAX 0 "Number of times the Threshold must be exceeded before Action is triggered"'
        tf.puts '  APPEND_PARAMETER "Type" 32 UINT 0 3 0 "How the Threshold is compared against"'
        tf.puts '    STATE LESS_THAN 0'
        tf.puts '    STATE GREATER_THAN 1'
        tf.puts '    STATE EQUAL_TO 2'
        tf.puts '    STATE NOT_EQUAL_TO 3'
        tf.puts '  APPEND_PARAMETER "Action" 32 UINT 0 4 0 "Action to take when Persistance is met"'
        tf.puts '    STATE NO_ACTION_REQUIRED 0'
        tf.puts '    STATE INITIATE_RESET 1'
        tf.puts '    STATE CHANGE_MODE_SAFE 2'
        tf.puts '  APPEND_PARAMETER "Group" 32 UINT 1 4 1 "Telemetry group this monitor item belongs to. Groups are automatically enabled due to payload events."'
        tf.puts '    STATE ALL_MODES 1'
        tf.puts '    STATE SAFE_MODE 2'
        tf.puts '  APPEND_PARAMETER "Signed" 8 UINT 0 2 0 "Whether to treat the Data Size data as signed or unsigned when comparing to the Threshold"'
        tf.puts '    STATE NOT_APPLICABLE 0'
        tf.puts '    STATE UNSIGNED 1'
        tf.puts '    STATE SIGNED 2'
        tf.close
        bin_file = core.file_new(tf.path, Dir.pwd)
        json = core.generate_json(bin_file, tf.path)
        result = JSON.parse(json)
        expect(result).to be_a Hash
        expect(result.keys).to eql ['TLM MONITORING']
        pp result
        expect(result['TLM MONITORING']["num_rows"]).to eql 10
        expect(result['TLM MONITORING']["num_columns"]).to eql 9
        # expect(result['TLM MONITORING']["rows"][0]
        File.delete(bin_file)
        tf.unlink
      end
    end

    describe "save_json" do
      it "save json to the binary" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE "PPS Selection" BIG_ENDIAN ONE_DIMENSIONAL "Payload Clock Control Pulse Per Second Selection Table"'
        tf.puts '  APPEND_PARAMETER "Primary PPS" 8 UINT 0 1 1'
        tf.puts '    STATE CHECKED 1'
        tf.puts '    STATE UNCHECKED 0'
        tf.puts '  APPEND_PARAMETER "Redundant PPS" 8 UINT 0 1 1'
        tf.puts '    UNEDITABLE'
        tf.puts '    STATE UNCHECKED 0'
        tf.puts '    STATE CHECKED 1'
        tf.close
        bin_file = core.file_new(tf.path, Dir.pwd)
        data = File.read(bin_file, mode: 'rb')
        expect(data).to eql "\x01\x01"
        json = core.generate_json(bin_file, tf.path)
        table = JSON.parse(json)
        table["PPS SELECTION"][0]['value'] = "UNCHECKED"
        table["PPS SELECTION"][1]['value'] = "UNCHECKED"
        bin_file = core.save_json(bin_file, tf.path, table)
        data =  File.read(bin_file, mode: 'rb')
        expect(data).to eql "\x00\x00"
        File.delete(bin_file)
        tf.unlink
      end
    end

    describe "reset" do
      it "clears the definition filename and configuration" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.close
        core.process_definition(tf.path)
        tf.unlink
        expect(core.config).to_not be_nil
        core.reset
        expect(core.config).to be_nil
      end
    end

    describe "file_new" do
      it "complains if the definition filename does not exist" do
        expect { core.file_new('path', Dir.pwd) }.to raise_error(/Configuration file path does not exist./)
      end

      it "creates a simple new file in the given output dir" do
        def_filename = File.join(Dir.pwd, 'table_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 32 UINT MIN MAX 0xDEADBEEF "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT 0 1 0 "Item"'
          file.puts '    STATE DISABLE 0'
          file.puts '    STATE ENABLE 1'
        end
        bin_filename = core.file_new(def_filename, Dir.pwd)
        expect(bin_filename).to eq File.join(Dir.pwd, "table.bin")
        expect(File.read(bin_filename).formatted).to match(/DE AD BE EF 00 00/)
        FileUtils.rm def_filename
        FileUtils.rm bin_filename
        FileUtils.rm 'table.csv'
      end
    end

    describe "file_open" do
      it "complains if the definition filename does not exist" do
        def_filename = File.join(Dir.pwd, 'def.txt')
        FileUtils.rm def_filename if File.exist? def_filename
        bin_filename = File.join(Dir.pwd, 'dat.bin')
        File.open(bin_filename,'w') {|file| file.puts "\x00\x01" }
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/does not exist/)
        FileUtils.rm bin_filename
      end

      it "complains if the binary filename does not exist" do
        bin_filename = File.join(Dir.pwd, 'bin.bin')
        FileUtils.rm bin_filename if File.exist? bin_filename
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') {|file| file.puts "TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL" }
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/Unable to open and load/)
        FileUtils.rm def_filename
      end

      it "complains if the binary filename isn't big enough for the definition and zero fills data" do
        bin_filename = File.join(Dir.pwd, 'bin.bin')
        File.open(bin_filename,'w') {|file| file.write "\xAB\xCD" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 32 UINT 0 0 0 "Item"'
        end
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/Binary size of 2 not large enough/)
        expect(core.config.tables['TABLE1'].buffer.formatted).to match(/AB CD 00 00/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "complains if the binary filename is too enough for the definition and truncates the data" do
        bin_filename = File.join(Dir.pwd, 'bin.bin')
        File.open(bin_filename,'w') {|file| file.write "\xAB\xCD\xEF" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
        end
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/Binary size of 3 larger/)
        expect(core.config.tables['TABLE1'].buffer.formatted).to match(/AB CD/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "file_save" do
      it "complains if there is no configuration" do
        expect { core.file_save('save') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if there is an error in the configuration data" do
        bin_filename = File.join(Dir.pwd, 'bin.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.file_save('save.bin') }.to raise_error(TableManagerCore::CoreError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "writes the configuration to file" do
        bin_filename = File.join(Dir.pwd, 'bin.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        core.config.tables['TABLE1'].buffer = "\xAB\xCD"
        core.file_save('save.bin')
        expect(File.read('save.bin').formatted).to match(/AB CD/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm 'save.bin'
        FileUtils.rm 'save.bin.csv'
      end
    end

    describe "file_check" do
      it "complains if there is no configuration" do
        expect { core.file_check() }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if there is an error in the configuration data" do
        bin_filename = File.join(Dir.pwd, 'bin.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.file_check() }.to raise_error(/Errors in TABLE1/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "returns a success string if there are no errors" do
        bin_filename = File.join(Dir.pwd, 'bin.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect(core.file_check()).to eql "All parameters are within their constraints."
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "file_report" do
      it "complains if there is no configuration" do
        expect { core.file_report('file.bin', 'file_def.txt') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "creates a CSV file with the configuration for ONE_DIMENSIONAL" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        report_filename = core.file_report(bin_filename, def_filename)
        expect(File.basename(report_filename)).to eql "testfile.csv"
        report = File.read(report_filename)
        expect(report).to match(/#{bin_filename}/)
        expect(report).to match(/#{def_filename}/)
        FileUtils.rm report_filename
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "creates a CSV file with the configuration for TWO_DIMENSIONAL" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01\x02\x03\x00\x01\x02\x03" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN TWO_DIMENSIONAL 2'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        report_filename = core.file_report(bin_filename, def_filename)
        expect(File.basename(report_filename)).to eql "testfile.csv"
        report = File.read(report_filename)
        expect(report).to match(/#{bin_filename}/)
        expect(report).to match(/#{def_filename}/)
        FileUtils.rm report_filename
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "file_hex" do
      it "complains if there is no configuration" do
        expect { core.file_hex }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "creates a hex representation of the binary data" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect(core.file_hex).to match(/Total Bytes Read: 4/)
        expect(core.file_hex).to match(/DE AD BE EF/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "table_check" do
      it "complains if there is no configuration" do
        expect { core.table_check('table') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x00" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_check('TABLE') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "returns a string with out of range values" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x03\xFF\xFD\x48\x46\x4C\x4C\x4F\x00\x00" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 2 0 "Item"'
          file.puts '    STATE DISABLE 0'
          file.puts '    STATE ENABLE 1'
          file.puts '    STATE UNKNOWN 2'
          file.puts '  APPEND_PARAMETER item2 16 INT -2 2 0 "Item"'
          file.puts '  APPEND_PARAMETER item3 40 STRING "HELLO" "Item"'
          file.puts '  APPEND_PARAMETER item4 16 UINT 0 4 0 "Item"'
          file.puts '    FORMAT_STRING "0x%0X"'
          file.puts '    GENERIC_READ_CONVERSION_START'
          file.puts '      myself.read("item1") * 2'
          file.puts '    GENERIC_READ_CONVERSION_END'
        end
        core.file_open(bin_filename, def_filename)
        result = core.table_check('table1')
        expect(result).to match("ITEM1: 3 outside valid range of 0..2")
        expect(result).to match("ITEM2: -3 outside valid range of -2..2")
        expect(result).to match("ITEM4: 0x6 outside valid range of 0x0..0x4")
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "table_default" do
      it "complains if there is no configuration" do
        expect { core.table_default('table') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x00" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_default('TABLE') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "sets all table items to their default" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00"*11 }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 INT MIN MAX -100 "Item"'
          file.puts '  APPEND_PARAMETER item2 32 UINT MIN MAX 0xDEADBEEF "Item"'
          file.puts '  APPEND_PARAMETER item3 40 STRING "HELLO" "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect(core.config.tables['TABLE1'].read('item1')).to eq 0
        expect(core.config.tables['TABLE1'].read('item2')).to eq 0
        expect(core.config.tables['TABLE1'].read('item3')).to eq ""
        core.table_default('table1')
        expect(core.config.tables['TABLE1'].read('item1')).to eq (-100)
        expect(core.config.tables['TABLE1'].read('item2')).to eq 0xDEADBEEF
        expect(core.config.tables['TABLE1'].read('item3')).to eq "HELLO"
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "table_hex" do
      it "complains if there is no configuration" do
        expect { core.table_hex('table') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_hex('table') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "creates a hex representation of the binary data" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF\xCA\xFE\xBA\xBE" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
          file.puts 'TABLE table2 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect(core.table_hex('table1')).to match(/Total Bytes Read: 4/)
        expect(core.table_hex('table1')).to match(/DE AD BE EF/)
        expect(core.table_hex('table2')).to match(/Total Bytes Read: 4/)
        expect(core.table_hex('table2')).to match(/CA FE BA BE/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "table_save" do
      it "complains if there is no configuration" do
        expect { core.table_save('table', 'table.bin') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_save('table', 'table.bin') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "complains if the table has errors" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_save('table1', 'table.bin') }.to raise_error(TableManagerCore::CoreError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "creates a new file with the table binary data" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF\xCA\xFE\xBA\xBE" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
          file.puts 'TABLE table2 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        core.table_save('table1', 'table1.bin')
        expect(File.read('table1.bin').formatted).to match(/DE AD BE EF/)
        core.table_save('table2', 'table2.bin')
        expect(File.read('table2.bin').formatted).to match(/CA FE BA BE/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm 'table1.bin'
        FileUtils.rm 'table2.bin'
      end
    end

    describe "table_commit" do
      it "complains if there is no configuration" do
        expect { core.table_commit('table', 'table.bin', 'table_def.txt') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_commit('table', 'testfile.bin', 'testfile_def.txt') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "complains if the table has errors" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_commit('table1', 'testfile.bin', 'testfile_def.txt') }.to raise_error(TableManagerCore::CoreError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "complains if the new definition has errors" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        new_def_filename = File.join(Dir.pwd, 'newtestfile_def.txt')
        File.open(new_def_filename,'w') do |file|
          file.puts 'TABLE table1'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_commit('table1', 'testfile.bin', 'newtestfile_def.txt') }.to raise_error(TableManagerCore::CoreError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm new_def_filename
      end

      it "complains if the new file doesn't define the table" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        new_def_filename = File.join(Dir.pwd, 'newtestfile_def.txt')
        File.open(new_def_filename,'w') do |file|
          file.puts 'TABLE table2 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_commit('table1', 'testfile.bin', 'newtestfile_def.txt') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm new_def_filename
      end

      it "saves the table binary data into a new file" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF\xCA\xFE\xBA\xBE" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
          file.puts 'TABLE table2 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        new_bin_filename = File.join(Dir.pwd, 'newtestfile.bin')
        File.open(new_bin_filename,'w') {|file| file.write "\x00"*8 }

        core.file_open(bin_filename, def_filename)
        expect(File.read('newtestfile.bin').formatted).to match(/00 00 00 00 00 00 00 00/)
        core.table_commit('table1', 'newtestfile.bin', 'testfile_def.txt')
        expect(File.read('newtestfile.bin').formatted).to match(/DE AD BE EF 00 00 00 00/)
        core.table_commit('table2', 'newtestfile.bin', 'testfile_def.txt')
        expect(File.read('newtestfile.bin').formatted).to match(/DE AD BE EF CA FE BA BE/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm new_bin_filename
        FileUtils.rm 'newtestfile.csv'
      end
    end

  end # describe TableManagerCore
end
