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
        tf.puts("TABLE table1 BIG_ENDIAN KEY_VALUE")
        tf.close
        core.process_definition(tf.path)
        tf.unlink
        expect(core.config).to_not be_nil
      end
    end

    describe "generate_json" do
      it "generates json from the KEY_VALUE table definition" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE "Test" BIG_ENDIAN KEY_VALUE "Description"'
        # Normal text value
        tf.puts '  APPEND_PARAMETER "Throttle" 32 UINT 0 0x0FFFFFFFF 0'
        tf.puts '    FORMAT_STRING "0x%0X"'
        # State value
        tf.puts '  APPEND_PARAMETER "Scrubbing" 8 UINT 0 1 0'
        tf.puts '    STATE DISABLE 0'
        tf.puts '    STATE ENABLE 1'
        # Checkbox value
        tf.puts '  APPEND_PARAMETER "PPS" 8 UINT 0 1 0'
        tf.puts '    STATE UNCHECKED 0'
        tf.puts '    STATE CHECKED 1'
        tf.puts '    UNEDITABLE'
        tf.close
        bin_file = core.file_new(tf.path, Dir.pwd)
        json = core.generate_json(bin_file, tf.path)
        File.delete(bin_file)
        result = JSON.parse(json)
        expect(result).to be_a Hash
        expect(result['tables'][0]["numRows"]).to eql 3
        expect(result['tables'][0]["numColumns"]).to eql 1
        expect(result['tables'][0]["headers"]).to eql %w(INDEX NAME VALUE)
        expect(result['tables'][0]["rows"][0][0]['index']).to eql 1
        expect(result['tables'][0]["rows"][0][0]['name']).to eql 'THROTTLE'
        expect(result['tables'][0]["rows"][0][0]['value']).to eql '0x0'
        expect(result['tables'][0]["rows"][0][0]['editable']).to be true
        expect(result['tables'][0]["rows"][1][0]['index']).to eql 2
        expect(result['tables'][0]["rows"][1][0]['name']).to eql 'SCRUBBING'
        expect(result['tables'][0]["rows"][1][0]['value']).to eql 'DISABLE'
        expect(result['tables'][0]["rows"][1][0]['editable']).to be true
        expect(result['tables'][0]["rows"][2][0]['index']).to eql 3
        expect(result['tables'][0]["rows"][2][0]['name']).to eql 'PPS'
        expect(result['tables'][0]["rows"][2][0]['value']).to eql 'UNCHECKED'
        expect(result['tables'][0]["rows"][2][0]['editable']).to be false

        # Generate json based on a new binary
        bin = Tempfile.new('table.bin')
        bin.write("\xDE\xAD\xBE\xEF\x01\x01")
        bin.close
        json = core.generate_json(bin.path, tf.path)
        result = JSON.parse(json)
        expect(result['tables'][0]["rows"][0][0]['value']).to eql '0xDEADBEEF'
        expect(result['tables'][0]["rows"][1][0]['value']).to eql 'ENABLE'
        expect(result['tables'][0]["rows"][2][0]['value']).to eql 'CHECKED'
        bin.unlink
        tf.unlink
      end

      it "generates json from the ROW_COLUMN table definition" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE "Test" BIG_ENDIAN ROW_COLUMN 3 "Description"'
        # Normal text value
        tf.puts '  APPEND_PARAMETER "Throttle" 32 UINT 0 0x0FFFFFFFF 0'
        tf.puts '    FORMAT_STRING "0x%0X"'
        # State value
        tf.puts '  APPEND_PARAMETER "Scrubbing" 8 UINT 0 1 0'
        tf.puts '    STATE DISABLE 0'
        tf.puts '    STATE ENABLE 1'
        # Checkbox value
        tf.puts '  APPEND_PARAMETER "PPS" 8 UINT 0 1 0'
        tf.puts '    STATE UNCHECKED 0'
        tf.puts '    STATE CHECKED 1'
        tf.puts '    UNEDITABLE'
        # Defaults
        tf.puts 'DEFAULT 0 0 0'
        tf.puts 'DEFAULT 0xDEADBEEF ENABLE CHECKED'
        tf.puts 'DEFAULT 0xBA5EBA11 DISABLE CHECKED'
        tf.close
        bin_file = core.file_new(tf.path, Dir.pwd)
        json = core.generate_json(bin_file, tf.path)
        result = JSON.parse(json)
        expect(result).to be_a Hash
        expect(result['tables'][0]["numRows"]).to eql 3
        expect(result['tables'][0]["numColumns"]).to eql 3
        expect(result['tables'][0]["headers"]).to eql %w(INDEX THROTTLE SCRUBBING PPS)
        expect(result['tables'][0]["rows"][0][0]['index']).to eql 1
        expect(result['tables'][0]["rows"][0][0]['value']).to eql '0x0'
        expect(result['tables'][0]["rows"][0][1]['value']).to eql 'DISABLE'
        expect(result['tables'][0]["rows"][0][2]['value']).to eql 'UNCHECKED'
        expect(result['tables'][0]["rows"][1][0]['index']).to eql 2
        expect(result['tables'][0]["rows"][1][0]['value']).to eql '0xDEADBEEF'
        expect(result['tables'][0]["rows"][1][1]['value']).to eql 'ENABLE'
        expect(result['tables'][0]["rows"][1][2]['value']).to eql 'CHECKED'
        expect(result['tables'][0]["rows"][2][0]['index']).to eql 3
        expect(result['tables'][0]["rows"][2][0]['value']).to eql '0xBA5EBA11'
        expect(result['tables'][0]["rows"][2][1]['value']).to eql 'DISABLE'
        expect(result['tables'][0]["rows"][2][2]['value']).to eql 'CHECKED'
        File.delete(bin_file)
        tf.unlink
      end
    end

    describe "save_tables" do
      it "saves single column table hash to the binary" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE "Test" BIG_ENDIAN KEY_VALUE "Description"'
        tf.puts '  APPEND_PARAMETER "Number" 16 UINT MIN MAX 0'
        tf.puts '  APPEND_PARAMETER "Throttle" 32 UINT 0 0x0FFFFFFFF 0'
        tf.puts '    FORMAT_STRING "0x%0X"'
        # State value
        tf.puts '  APPEND_PARAMETER "Scrubbing" 8 UINT 0 1 0'
        tf.puts '    STATE DISABLE 0'
        tf.puts '    STATE ENABLE 1'
        # Checkbox value
        tf.puts '  APPEND_PARAMETER "PPS" 8 UINT 0 1 0'
        tf.puts '    STATE UNCHECKED 0'
        tf.puts '    STATE CHECKED 1'
        tf.close
        bin_file = core.file_new(tf.path, Dir.pwd)
        data = File.read(bin_file, mode: 'rb')
        expect(data).to eql "\x00\x00\x00\x00\x00\x00\x00\x00"
        json = core.generate_json(bin_file, tf.path)
        result = JSON.parse(json)
        result['tables'][0]['rows'][0][0]['value'] = "1"
        result['tables'][0]['rows'][1][0]['value'] = "0x1234"
        result['tables'][0]['rows'][2][0]['value'] = "ENABLE"
        result['tables'][0]['rows'][3][0]['value'] = "CHECKED"
        bin_file = core.save_tables(bin_file, tf.path, result['tables'])
        data =  File.read(bin_file, mode: 'rb')
        expect(data).to eql "\x00\x01\x00\x00\x12\x34\x01\x01"
        File.delete(bin_file)
        tf.unlink
      end

      it "saves multi-column table hash to the binary" do
        tf = Tempfile.new('unittest')
        tf.puts 'TABLE "Test" BIG_ENDIAN ROW_COLUMN 3 "Description"'
        # Normal text value
        tf.puts '  APPEND_PARAMETER "Throttle" 32 UINT 0 0x0FFFFFFFF 0'
        tf.puts '    FORMAT_STRING "0x%0X"'
        # State value
        tf.puts '  APPEND_PARAMETER "Scrubbing" 8 UINT 0 1 0'
        tf.puts '    STATE DISABLE 0'
        tf.puts '    STATE ENABLE 1'
        # Checkbox value
        tf.puts '  APPEND_PARAMETER "PPS" 8 UINT 0 1 0'
        tf.puts '    STATE UNCHECKED 0'
        tf.puts '    STATE CHECKED 1'
        # Defaults
        tf.puts 'DEFAULT 0 0 0'
        tf.puts 'DEFAULT 0xDEADBEEF ENABLE CHECKED'
        tf.puts 'DEFAULT 0xBA5EBA11 DISABLE CHECKED'
        tf.close
        bin_file = core.file_new(tf.path, Dir.pwd)
        data = File.read(bin_file, mode: 'rb')
        expect(data).to eql "\x00\x00\x00\x00\x00\x00\xDE\xAD\xBE\xEF\x01\x01\xBA\x5E\xBA\x11\x00\x01"
        json = core.generate_json(bin_file, tf.path)
        result = JSON.parse(json)
        result['tables'][0]['rows'][0][0]['value'] = "1"
        result['tables'][0]['rows'][0][1]['value'] = "ENABLE"
        result['tables'][0]['rows'][0][2]['value'] = "CHECKED"
        result['tables'][0]['rows'][1][0]['value'] = "2"
        result['tables'][0]['rows'][1][1]['value'] = "DISABLE"
        result['tables'][0]['rows'][1][2]['value'] = "UNCHECKED"
        result['tables'][0]['rows'][2][0]['value'] = "3"
        result['tables'][0]['rows'][2][1]['value'] = "ENABLE"
        result['tables'][0]['rows'][2][2]['value'] = "UNCHECKED"
        bin_file = core.save_tables(bin_file, tf.path, result['tables'])
        data =  File.read(bin_file, mode: 'rb')
        expect(data).to eql "\x00\x00\x00\x01\x01\x01\x00\x00\x00\x02\x00\x00\x00\x00\x00\x03\x01\x00"
        File.delete(bin_file)
        tf.unlink
      end
    end

    describe "reset" do
      it "clears the definition filename and configuration" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table1 BIG_ENDIAN KEY_VALUE")
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
        File.open(def_filename,'w') {|file| file.puts "TABLE table1 BIG_ENDIAN KEY_VALUE" }
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/Unable to open and load/)
        FileUtils.rm def_filename
      end

      it "complains if the binary filename isn't big enough for the definition and zero fills data" do
        bin_filename = File.join(Dir.pwd, 'bin.bin')
        File.open(bin_filename,'w') {|file| file.write "\xAB\xCD" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        core.config.tables['TABLE1'].buffer = "\xAB\xCD"
        core.file_save('save.bin')
        expect(File.read('save.bin').formatted).to match(/AB CD/)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm 'save.bin'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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

      it "creates a CSV file with the configuration for KEY_VALUE" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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

      it "creates a CSV file with the configuration for ROW_COLUMN" do
        bin_filename = File.join(Dir.pwd, 'testfile.bin')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01\x02\x03\x00\x01\x02\x03" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ROW_COLUMN 2'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
          file.puts 'TABLE table2 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
          file.puts 'TABLE table2 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        new_def_filename = File.join(Dir.pwd, 'newtestfile_def.txt')
        File.open(new_def_filename,'w') do |file|
          file.puts 'TABLE table2 BIG_ENDIAN KEY_VALUE'
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
          file.puts 'TABLE table1 BIG_ENDIAN KEY_VALUE'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
          file.puts 'TABLE table2 BIG_ENDIAN KEY_VALUE'
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
      end
    end

  end # describe TableManagerCore
end
