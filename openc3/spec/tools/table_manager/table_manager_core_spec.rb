# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'spec_helper'
require 'openc3'
require 'openc3/tools/table_manager/table_manager_core'

module OpenC3
  describe TableManagerCore do
    describe "self.binary" do
      it "pulls out a table binary from a multi-table file" do
        tmp = File.join(SPEC_DIR, 'tmp')
        Dir.mkdir(tmp) unless File.exist?(tmp)
        def_path = "#{tmp}/tabledef.txt"
        File.open(def_path, 'w') do |file|
          file.puts('TABLEFILE "TestTable1_def.txt"')
          file.puts('TABLEFILE "TestTable2_def.txt"')
          file.puts('TABLEFILE "TestTable3_def.txt"')
        end
        File.open("#{tmp}/TestTable1_def.txt", 'w') do |file|
          file.puts 'TABLE "Test1" BIG_ENDIAN KEY_VALUE'
          file.puts '  APPEND_PARAMETER "8bit" 8 UINT 0 0xFF 1'
        end
        File.open("#{tmp}/TestTable2_def.txt", 'w') do |file|
          file.puts 'TABLE "Test2" BIG_ENDIAN KEY_VALUE'
          file.puts '  APPEND_PARAMETER "16bit" 16 UINT 0 0xFFFF 2'
        end
        File.open("#{tmp}/TestTable3_def.txt", 'w') do |file|
          file.puts 'TABLE "Test3" BIG_ENDIAN KEY_VALUE'
          file.puts '  APPEND_PARAMETER "32bit" 32 UINT 0 0xFFFFFFFFF 3'
        end

        binary = TableManagerCore.binary("\x01\x02\x03\x04\x05\x06\x07", def_path, 'TEST1')
        expect(binary).to eql "\x01"
        binary = TableManagerCore.binary("\x01\x02\x03\x04\x05\x06\x07", def_path, 'TEST2')
        expect(binary).to eql "\x02\x03"
        binary = TableManagerCore.binary("\x01\x02\x03\x04\x05\x06\x07", def_path, 'TEST3')
        expect(binary).to eql "\x04\x05\x06\x07"
        FileUtils.rm_rf(tmp)
      end
    end

    describe "self.definition" do
      it "pulls out a table definition from a multi-table file" do
        tmp = File.join(SPEC_DIR, 'tmp')
        Dir.mkdir(tmp) unless File.exist?(tmp)
        def_path = "#{tmp}/tabledef.txt"
        File.open(def_path, 'w') do |file|
          file.puts('TABLEFILE "TestTable1_def.txt"')
          file.puts('TABLEFILE "TestTable2_def.txt"')
          file.puts('TABLEFILE "TestTable3_def.txt"')
        end
        def1 = "TABLE 'Test1' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '8bit' 8 UINT 0 0xFF 1"
        File.write("#{tmp}/TestTable1_def.txt", def1)
        def2 = "TABLE 'Test2' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '16bit' 16 UINT 0 0xFFFF 2"
        File.write("#{tmp}/TestTable2_def.txt", def2)
        def3 = "TABLE 'Test3' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '32bit' 32 UINT 0 0xFFFFFFFF 2"
        File.write("#{tmp}/TestTable3_def.txt", def3)

        definition = TableManagerCore.definition(def_path, 'TEST1')
        expect(definition[0]).to eql 'TestTable1_def.txt'
        expect(definition[1]).to eql def1
        definition = TableManagerCore.definition(def_path, 'TEST2')
        expect(definition[0]).to eql 'TestTable2_def.txt'
        expect(definition[1]).to eql def2
        definition = TableManagerCore.definition(def_path, 'TEST3')
        expect(definition[0]).to eql 'TestTable3_def.txt'
        expect(definition[1]).to eql def3
        FileUtils.rm_rf(tmp)
      end
    end

    describe "self.report" do
      it "creates a report for a file or a table" do
        tmp = File.join(SPEC_DIR, 'tmp')
        Dir.mkdir(tmp) unless File.exist?(tmp)
        def_path = "#{tmp}/tabledef.txt"
        File.open(def_path, 'w') do |file|
          file.puts('TABLEFILE "TestTable1_def.txt"')
          file.puts('TABLEFILE "TestTable2_def.txt"')
          file.puts('TABLEFILE "TestTable3_def.txt"')
        end
        def1 = "TABLE 'Test1' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '8bit' 8 UINT 0 0xFF 1"
        File.write("#{tmp}/TestTable1_def.txt", def1)
        def2 = "TABLE 'Test2' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '16bit' 16 UINT 0 0xFFFF 2"
        File.write("#{tmp}/TestTable2_def.txt", def2)
        def3 = "TABLE 'Test3' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '32bit' 32 UINT 0 0xFFFFFFFF 2"
        File.write("#{tmp}/TestTable3_def.txt", def3)

        report = TableManagerCore.report("\x01\x02\x03\x04\x05\x06\x07", def_path)
        expect(report).to include("TEST1")
        expect(report).to include("TEST2")
        expect(report).to include("TEST3")
        report = TableManagerCore.report("\x01\x02\x03\x04\x05\x06\x07", def_path, 'TEST1')
        expect(report).to include("TEST1")
        expect(report).not_to include("TEST2")
        expect(report).not_to include("TEST3")
        report = TableManagerCore.report("\x01\x02\x03\x04\x05\x06\x07", def_path, 'TEST2')
        expect(report).not_to include("TEST1")
        expect(report).to include("TEST2")
        expect(report).not_to include("TEST3")
        report = TableManagerCore.report("\x01\x02\x03\x04\x05\x06\x07", def_path, 'TEST3')
        expect(report).not_to include("TEST1")
        expect(report).not_to include("TEST2")
        expect(report).to include("TEST3")
        FileUtils.rm_rf(tmp)
      end
    end

    describe "self.generate" do
      it "generates a binary based on definition" do
        tmp = File.join(SPEC_DIR, 'tmp')
        Dir.mkdir(tmp) unless File.exist?(tmp)
        def_path = "#{tmp}/tabledef.txt"
        File.open(def_path, 'w') do |file|
          file.puts('TABLEFILE "TestTable1_def.txt"')
          file.puts('TABLEFILE "TestTable2_def.txt"')
          file.puts('TABLEFILE "TestTable3_def.txt"')
        end
        def1 = "TABLE 'Test1' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '8bit' 8 UINT 0 0xFF 1"
        File.write("#{tmp}/TestTable1_def.txt", def1)
        def2 = "TABLE 'Test2' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '16bit' 16 UINT 0 0xFFFF 0xABCD"
        File.write("#{tmp}/TestTable2_def.txt", def2)
        def3 = "TABLE 'Test3' BIG_ENDIAN KEY_VALUE\n  APPEND_PARAMETER '32bit' 32 UINT 0 0xFFFFFFFF 0xDEADBEEF"
        File.write("#{tmp}/TestTable3_def.txt", def3)

        binary = TableManagerCore.generate(def_path)
        expect(binary).to eql("\x01\xAB\xCD\xDE\xAD\xBE\xEF")
        FileUtils.rm_rf(tmp)
      end

      it "generates a binary with all the fields" do
        tmp = File.join(SPEC_DIR, 'tmp')
        Dir.mkdir(tmp) unless File.exist?(tmp)
        def_path = "#{tmp}/tabledef.txt"
        File.open(def_path, 'w') do |file|
          file.puts('TABLE "MC_Configuration" BIG_ENDIAN KEY_VALUE "Memory Control Configuration Table"')
          file.puts('APPEND_PARAMETER "UINT" 32 UINT 0 0x3FFFFF 0x3FFFFF')
          file.puts('  FORMAT_STRING "0x%0X"')
          file.puts('APPEND_PARAMETER "FLOAT" 32 FLOAT MIN MAX 1.234')
          file.puts('APPEND_PARAMETER "STATE" 8 UINT 0 1 1')
          file.puts('  STATE DISABLE 0')
          file.puts('  STATE ENABLE 1')
          file.puts('APPEND_PARAMETER "Convert" 8 UINT 1 3 3')
          file.puts('GENERIC_WRITE_CONVERSION_START')
          file.puts('  value * 2')
          file.puts('GENERIC_WRITE_CONVERSION_END')
          file.puts('APPEND_PARAMETER "UNEDITABLE" 16 UINT MIN MAX 0 "Uneditable field"')
          file.puts('  UNEDITABLE')
          file.puts('APPEND_PARAMETER "BINARY" 32 STRING 0xBA5EBA11 "Binary string"')
          file.puts('APPEND_PARAMETER "Pad" 16 UINT 0 0 0')
          file.puts('  HIDDEN')
        end
        binary = TableManagerCore.generate(def_path)
        expect(binary).to eql("\x00\x3F\xFF\xFF\x3f\x9d\xf3\xb6\x01\x06\x00\x00\xBA\x5E\xBA\x11\x00\x00")
        FileUtils.rm_rf(tmp)
      end
    end

    describe "self.build_json & self.save" do
      it "saves single column table hash to the binary" do
        tmp = File.join(SPEC_DIR, 'tmp')
        Dir.mkdir(tmp) unless File.exist?(tmp)
        def_path = "#{tmp}/tabledef.txt"
        File.open(def_path, 'w') do |file|
          file.puts 'TABLE "Test" BIG_ENDIAN KEY_VALUE "Description"'
          file.puts '  APPEND_PARAMETER "Number" 16 UINT MIN MAX 0'
          file.puts '  APPEND_PARAMETER "Throttle" 32 UINT 0 0x0FFFFFFFF 0'
          file.puts '    FORMAT_STRING "0x%0X"'
          # State value
          file.puts '  APPEND_PARAMETER "Scrubbing" 8 UINT 0 1 0'
          file.puts '    STATE DISABLE 0'
          file.puts '    STATE ENABLE 1'
          # Checkbox value
          file.puts '  APPEND_PARAMETER "PPS" 8 UINT 0 1 0'
          file.puts '    STATE UNCHECKED 0'
          file.puts '    STATE CHECKED 1'
          file.puts '    UNEDITABLE'
        end

        json = TableManagerCore.build_json("\x00\x00\x00\x00\x00\x00\x00\x00", def_path)
        result = JSON.parse(json, :allow_nan => true, :create_additions => true)
        expect(result).to be_a Hash
        expect(result['tables'][0]["numRows"]).to eql 4
        expect(result['tables'][0]["numColumns"]).to eql 1
        expect(result['tables'][0]["headers"]).to eql %w(INDEX NAME VALUE)
        expect(result['tables'][0]["rows"][0][0]['index']).to eql 1
        expect(result['tables'][0]["rows"][0][0]['name']).to eql 'NUMBER'
        expect(result['tables'][0]["rows"][0][0]['value']).to eql '0'
        expect(result['tables'][0]["rows"][0][0]['editable']).to be true
        expect(result['tables'][0]["rows"][1][0]['index']).to eql 2
        expect(result['tables'][0]["rows"][1][0]['name']).to eql 'THROTTLE'
        expect(result['tables'][0]["rows"][1][0]['value']).to eql '0x0'
        expect(result['tables'][0]["rows"][1][0]['editable']).to be true
        expect(result['tables'][0]["rows"][2][0]['index']).to eql 3
        expect(result['tables'][0]["rows"][2][0]['name']).to eql 'SCRUBBING'
        expect(result['tables'][0]["rows"][2][0]['value']).to eql 'DISABLE'
        expect(result['tables'][0]["rows"][2][0]['editable']).to be true
        expect(result['tables'][0]["rows"][3][0]['index']).to eql 4
        expect(result['tables'][0]["rows"][3][0]['name']).to eql 'PPS'
        expect(result['tables'][0]["rows"][3][0]['value']).to eql 'UNCHECKED'
        expect(result['tables'][0]["rows"][3][0]['editable']).to be false

        result['tables'][0]['rows'][0][0]['value'] = "1"
        result['tables'][0]['rows'][1][0]['value'] = "0x1234"
        result['tables'][0]['rows'][2][0]['value'] = "ENABLE"
        result['tables'][0]['rows'][3][0]['value'] = "CHECKED"
        binary = TableManagerCore.save(def_path, result['tables'])
        expect(binary).to eql "\x00\x01\x00\x00\x12\x34\x01\x01"
      end

      it "saves multi-column table hash to the binary" do
        tmp = File.join(SPEC_DIR, 'tmp')
        Dir.mkdir(tmp) unless File.exist?(tmp)
        def_path = "#{tmp}/tabledef.txt"
        File.open(def_path, 'w') do |file|
          file.puts 'TABLE "Test" BIG_ENDIAN ROW_COLUMN 3 "Description"'
          # Normal text value
          file.puts '  APPEND_PARAMETER "Throttle" 32 UINT 0 0x0FFFFFFFF 0'
          file.puts '    FORMAT_STRING "0x%0X"'
          # State value
          file.puts '  APPEND_PARAMETER "Scrubbing" 8 UINT 0 1 0'
          file.puts '    STATE DISABLE 0'
          file.puts '    STATE ENABLE 1'
          # Checkbox value
          file.puts '  APPEND_PARAMETER "PPS" 8 UINT 0 1 0'
          file.puts '    STATE UNCHECKED 0'
          file.puts '    STATE CHECKED 1'
          # Defaults
          file.puts 'DEFAULT 0 0 0'
          file.puts 'DEFAULT 0xDEADBEEF ENABLE CHECKED'
          file.puts 'DEFAULT 0xBA5EBA11 DISABLE CHECKED'
        end

        json = TableManagerCore.build_json("\x00\x00\x00\x00\x00\x00\xDE\xAD\xBE\xEF\x01\x01\xBA\x5E\xBA\x11\x00\x01", def_path)
        result = JSON.parse(json, :allow_nan => true, :create_additions => true)
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

        result['tables'][0]['rows'][0][0]['value'] = "1"
        result['tables'][0]['rows'][0][1]['value'] = "ENABLE"
        result['tables'][0]['rows'][0][2]['value'] = "CHECKED"
        result['tables'][0]['rows'][1][0]['value'] = "2"
        result['tables'][0]['rows'][1][1]['value'] = "DISABLE"
        result['tables'][0]['rows'][1][2]['value'] = "UNCHECKED"
        result['tables'][0]['rows'][2][0]['value'] = "3"
        result['tables'][0]['rows'][2][1]['value'] = "ENABLE"
        result['tables'][0]['rows'][2][2]['value'] = "UNCHECKED"
        binary = TableManagerCore.save(def_path, result['tables'])
        expect(binary).to eql "\x00\x00\x00\x01\x01\x01\x00\x00\x00\x02\x00\x00\x00\x00\x00\x03\x01\x00"
      end
    end
  end
end
