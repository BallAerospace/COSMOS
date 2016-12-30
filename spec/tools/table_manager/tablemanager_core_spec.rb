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
        expect { core.process_definition('path') }.to raise_error(/No such file/)
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
        expect { core.file_new('path', Dir.pwd) }.to raise_error(/No such file/)
      end

      it "creates a new file in the given output dir" do
        def_filename = File.join(Dir.pwd, 'table_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 32 UINT MIN MAX 0xDEADBEEF "Item"'
        end
        bin_filename = core.file_new(def_filename, Dir.pwd)
        expect(bin_filename).to eq File.join(Dir.pwd, "table.dat")
        expect(File.read(bin_filename).formatted).to match /DE AD BE EF/
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
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/No such file/)
        FileUtils.rm bin_filename
      end

      it "complains if the binary filename does not exist" do
        bin_filename = File.join(Dir.pwd, 'bin.dat')
        FileUtils.rm bin_filename if File.exist? bin_filename
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') {|file| file.puts "TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL" }
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/No such file/)
        FileUtils.rm def_filename
      end

      it "complains if the binary filename isn't big enough for the definition and zero fills data" do
        bin_filename = File.join(Dir.pwd, 'bin.dat')
        File.open(bin_filename,'w') {|file| file.write "\xAB\xCD" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 32 UINT 0 0 0 "Item"'
        end
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/Binary size of 2 not large enough/)
        expect(core.config.tables['TABLE1'].buffer.formatted).to match /AB CD 00 00/
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "complains if the binary filename is too enough for the definition and truncates the data" do
        bin_filename = File.join(Dir.pwd, 'bin.dat')
        File.open(bin_filename,'w') {|file| file.write "\xAB\xCD\xEF" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
        end
        expect { core.file_open(bin_filename, def_filename) }.to raise_error(/Binary size of 3 larger/)
        expect(core.config.tables['TABLE1'].buffer.formatted).to match /AB CD/
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "file_save" do
      it "complains if there is no configuration" do
        expect { core.file_save('save') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if there is an error in the configuration data" do
        bin_filename = File.join(Dir.pwd, 'bin.dat')
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
        bin_filename = File.join(Dir.pwd, 'bin.dat')
        File.open(bin_filename,'w') {|file| file.write "\x00\x01" }
        def_filename = File.join(Dir.pwd, 'def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        core.config.tables['TABLE1'].buffer = "\xAB\xCD"
        core.file_save('save.bin')
        expect(File.read('save.bin').formatted).to match /AB CD/
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
        bin_filename = File.join(Dir.pwd, 'bin.dat')
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
        bin_filename = File.join(Dir.pwd, 'bin.dat')
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
        expect { core.file_report('file.dat', 'file_def.txt') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "creates a CSV file with the configuration for ONE_DIMENSIONAL" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        expect(report).to match /#{bin_filename}/
        expect(report).to match /#{def_filename}/
        FileUtils.rm report_filename
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "creates a CSV file with the configuration for TWO_DIMENSIONAL" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        expect(report).to match /#{bin_filename}/
        expect(report).to match /#{def_filename}/
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
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect(core.file_hex).to match /Total Bytes Read: 4/
        expect(core.file_hex).to match /DE AD BE EF/
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "table_check" do
      it "complains if there is no configuration" do
        expect { core.table_check('table') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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

      it "returns a strings with out of range values" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
        File.open(bin_filename,'w') {|file| file.write "\x00\x03\xFF\xFD\x48\x46\x4C\x4C\x4F\x00\x00" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 2 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 INT -2 2 0 "Item"'
          file.puts '  APPEND_PARAMETER item3 40 STRING "HELLO" "Item"'
          file.puts '  APPEND_PARAMETER item4 16 UINT 0 4 0 "Item"'
          file.puts '    GENERIC_READ_CONVERSION_START'
          file.puts '      myself.read("item1") * 2'
          file.puts '    GENERIC_READ_CONVERSION_END'
        end
        core.file_open(bin_filename, def_filename)
        result = core.table_check('table1')
        expect(result).to match /ITEM1: 3 outside valid range/
        expect(result).to match /ITEM2: -3 outside valid range/
        expect(result).to match /ITEM4: 6 outside valid range/
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "table_default" do
      it "complains if there is no configuration" do
        expect { core.table_default('table') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        expect(core.config.tables['TABLE1'].read('item1')).to eq -100
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
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        expect(core.table_hex('table1')).to match /Total Bytes Read: 4/
        expect(core.table_hex('table1')).to match /DE AD BE EF/
        expect(core.table_hex('table2')).to match /Total Bytes Read: 4/
        expect(core.table_hex('table2')).to match /CA FE BA BE/
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end
    end

    describe "table_save" do
      it "complains if there is no configuration" do
        expect { core.table_save('table', 'table.dat') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_save('table', 'table.dat') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "complains if the table has errors" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_save('table1', 'table.dat') }.to raise_error(TableManagerCore::CoreError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "creates a new file with the table binary data" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        core.table_save('table1', 'table1.dat')
        expect(File.read('table1.dat').formatted).to match /DE AD BE EF/
        core.table_save('table2', 'table2.dat')
        expect(File.read('table2.dat').formatted).to match /CA FE BA BE/
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm 'table1.dat'
        FileUtils.rm 'table2.dat'
      end
    end

    describe "table_commit" do
      it "complains if there is no configuration" do
        expect { core.table_commit('table', 'table.dat', 'table_def.txt') }.to raise_error(TableManagerCore::NoConfigError)
      end

      it "complains if the table does not exist" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT MIN MAX 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_commit('table', 'testfile.dat', 'testfile_def.txt') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "complains if the table has errors" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
        File.open(bin_filename,'w') {|file| file.write "\xDE\xAD\xBE\xEF" }
        def_filename = File.join(Dir.pwd, 'testfile_def.txt')
        File.open(def_filename,'w') do |file|
          file.puts 'TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL'
          file.puts '  APPEND_PARAMETER item1 16 UINT 0 0 0 "Item"'
          file.puts '  APPEND_PARAMETER item2 16 UINT MIN MAX 0 "Item"'
        end
        core.file_open(bin_filename, def_filename)
        expect { core.table_commit('table1', 'testfile.dat', 'testfile_def.txt') }.to raise_error(TableManagerCore::CoreError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
      end

      it "complains if the new file doesn't define the table" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        expect { core.table_commit('table1', 'testfile.dat', 'newtestfile_def.txt') }.to raise_error(TableManagerCore::NoTableError)
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm new_def_filename
      end

      it "saves the table binary data into a new file" do
        bin_filename = File.join(Dir.pwd, 'testfile.dat')
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
        new_bin_filename = File.join(Dir.pwd, 'newtestfile.dat')
        File.open(new_bin_filename,'w') {|file| file.write "\x00"*8 }

        core.file_open(bin_filename, def_filename)
        expect(File.read('newtestfile.dat').formatted).to match /00 00 00 00 00 00 00 00/
        core.table_commit('table1', 'newtestfile.dat', 'testfile_def.txt')
        expect(File.read('newtestfile.dat').formatted).to match /DE AD BE EF 00 00 00 00/
        core.table_commit('table2', 'newtestfile.dat', 'testfile_def.txt')
        expect(File.read('newtestfile.dat').formatted).to match /DE AD BE EF CA FE BA BE/
        FileUtils.rm bin_filename
        FileUtils.rm def_filename
        FileUtils.rm new_bin_filename
        FileUtils.rm 'newtestfile.csv'
      end
    end

  end # describe TableManagerCore
end

