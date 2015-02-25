# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/buffered_file'

module Cosmos

  describe BufferedFile do
    DATA = "RyanSaysHelloToU"

    before(:all) do
      @filename = File.join(System.paths['LOGS'], 'test.bin')
      File.open(@filename, 'wb') do |file|
        file.write DATA * (2 * BufferedFile::BUFFER_SIZE / DATA.length)
      end
    end

    after(:all) do
      clean_config()
    end

    describe "read" do
      it "reads less than the buffer size" do
        file = BufferedFile.open(@filename, "rb") do |file|
          file.read(8).should eql DATA[0..7]
          file.pos.should eql 8
          file.read(4).should eql DATA[8..11]
          file.pos.should eql 12
          file.read(1).should eql DATA[12..12]
          file.pos.should eql 13
          file.read(3).should eql DATA[13..15]
          file.pos.should eql 16
          file.read(16).should eql DATA
          file.pos.should eql 32
          expected_pos = 32
          while (expected_pos < (2 * BufferedFile::BUFFER_SIZE))
            file.read(16).should eql DATA
            expected_pos += 16
            file.pos.should eql expected_pos
          end
          file.read(1).should be_nil
        end
      end

      it "reads equal to the buffer size" do
        file = BufferedFile.open(@filename, "rb") do |file|
          file.read(BufferedFile::BUFFER_SIZE).should eql(DATA * (BufferedFile::BUFFER_SIZE / DATA.length))
          file.pos.should eql BufferedFile::BUFFER_SIZE
          file.read(BufferedFile::BUFFER_SIZE).should eql(DATA * (BufferedFile::BUFFER_SIZE / DATA.length))
          file.pos.should eql BufferedFile::BUFFER_SIZE * 2
          file.read(BufferedFile::BUFFER_SIZE).should be_nil
        end
      end

      it "reads greater than the buffer size" do
        file = BufferedFile.open(@filename, "rb") do |file|
          file.read(BufferedFile::BUFFER_SIZE + 1).should eql(DATA * (BufferedFile::BUFFER_SIZE / DATA.length) << DATA[0..0])
          file.pos.should eql BufferedFile::BUFFER_SIZE + 1
          file.read(BufferedFile::BUFFER_SIZE + 1).should eql((DATA * (BufferedFile::BUFFER_SIZE / DATA.length))[1..-1])
          file.pos.should eql BufferedFile::BUFFER_SIZE * 2
          file.read(BufferedFile::BUFFER_SIZE + 1).should be_nil
        end
      end
    end

    describe "seek" do
      it "has reads still work afterwards" do
        file = BufferedFile.open(@filename, "rb") do |file|
          file.read(8).should eql DATA[0..7]
          file.pos.should eql 8
          file.seek(4, IO::SEEK_CUR)
          file.pos.should eql 12
          file.read(1).should eql DATA[12..12]
          file.pos.should eql 13
          file.read(3).should eql DATA[13..15]
          file.pos.should eql 16
          file.seek(0, IO::SEEK_SET)
          file.pos.should eql 0
          file.read(8).should eql DATA[0..7]
          file.pos.should eql 8
          file.seek(0, IO::SEEK_END)
          file.pos.should eql (2 * BufferedFile::BUFFER_SIZE)
          file.seek(-16, IO::SEEK_END)
          file.pos.should eql ((2 * BufferedFile::BUFFER_SIZE) - 16)
          file.read(4).should eql DATA[0..3]
          file.pos.should eql ((2 * BufferedFile::BUFFER_SIZE) - 12)
          file.seek(4, IO::SEEK_CUR)
          file.pos.should eql ((2 * BufferedFile::BUFFER_SIZE) - 8)
          file.seek(0, IO::SEEK_SET)
          file.pos.should eql 0
          file.read(8).should eql DATA[0..7]
          file.pos.should eql 8
          file.seek(4, IO::SEEK_CUR)
          file.pos.should eql 12
          file.read(1).should eql DATA[12..12]
          file.pos.should eql 13
          file.read(3).should eql DATA[13..15]
          file.pos.should eql 16
        end
      end
    end

  end
end

