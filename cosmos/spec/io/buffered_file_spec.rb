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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/io/buffered_file'

module Cosmos
  describe BufferedFile, no_ext: true do
    DATA = "RyanSaysHelloToU"

    before(:all) do
      @filename = File.join(File.dirname(__FILE__), 'test.bin')
      File.open(@filename, 'wb') do |file|
        file.write DATA * (2 * BufferedFile::BUFFER_SIZE / DATA.length)
      end
    end
    after(:all) do
      FileUtils.rm_f @filename
    end

    describe "read" do
      it "reads less than the buffer size" do
        BufferedFile.open(@filename, "rb") do |file|
          expect(file.read(8)).to eql DATA[0..7]
          expect(file.pos).to eql 8
          expect(file.read(4)).to eql DATA[8..11]
          expect(file.pos).to eql 12
          expect(file.read(1)).to eql DATA[12..12]
          expect(file.pos).to eql 13
          expect(file.read(3)).to eql DATA[13..15]
          expect(file.pos).to eql 16
          expect(file.read(16)).to eql DATA
          expect(file.pos).to eql 32
          expected_pos = 32
          while expected_pos < (2 * BufferedFile::BUFFER_SIZE)
            expect(file.read(16)).to eql DATA
            expected_pos += 16
            expect(file.pos).to eql expected_pos
          end
          expect(file.read(1)).to be_nil
        end
      end

      it "handles trying to read past the end" do
        BufferedFile.open(@filename, "rb") do |file|
          file.seek(-16, IO::SEEK_END)
          expect(file.pos).to eql ((2 * BufferedFile::BUFFER_SIZE) - 16)
          expect(file.read(DATA.length * 10)).to eql(DATA)
          expect(file.pos).to eql BufferedFile::BUFFER_SIZE * 2
          expect(file.read(DATA.length)).to be_nil
          expect(file.pos).to eql BufferedFile::BUFFER_SIZE * 2
        end
      end

      it "reads equal to the buffer size" do
        BufferedFile.open(@filename, "rb") do |file|
          expect(file.read(BufferedFile::BUFFER_SIZE)).to eql(DATA * (BufferedFile::BUFFER_SIZE / DATA.length))
          expect(file.pos).to eql BufferedFile::BUFFER_SIZE
          expect(file.read(BufferedFile::BUFFER_SIZE)).to eql(DATA * (BufferedFile::BUFFER_SIZE / DATA.length))
          expect(file.pos).to eql BufferedFile::BUFFER_SIZE * 2
          expect(file.read(BufferedFile::BUFFER_SIZE)).to be_nil
        end
      end

      it "reads greater than the buffer size" do
        BufferedFile.open(@filename, "rb") do |file|
          expect(file.read(BufferedFile::BUFFER_SIZE + 1)).to eql(DATA * (BufferedFile::BUFFER_SIZE / DATA.length) << DATA[0..0])
          expect(file.pos).to eql BufferedFile::BUFFER_SIZE + 1
          expect(file.read(BufferedFile::BUFFER_SIZE + 1)).to eql((DATA * (BufferedFile::BUFFER_SIZE / DATA.length))[1..-1])
          expect(file.pos).to eql BufferedFile::BUFFER_SIZE * 2
          expect(file.read(BufferedFile::BUFFER_SIZE + 1)).to be_nil
        end
      end

      it "reads greater than the buffer size after a previous read" do
        BufferedFile.open(@filename, "rb") do |file|
          expect(file.read(DATA.length * 10)).to eql(DATA * 10)
          expect(file.pos).to eql DATA.length * 10
          expect(file.read(BufferedFile::BUFFER_SIZE + 1)).to eql(DATA * ((BufferedFile::BUFFER_SIZE + 10) / DATA.length) << DATA[0])
          expect(file.pos).to eql(DATA.length * 10 + BufferedFile::BUFFER_SIZE + 1)
        end
      end
    end

    describe "seek" do
      it "raises if given more than 2 arguments" do
        BufferedFile.open(@filename, "rb") do |file|
          expect { file.seek(0, 4, IO::SEEK_CUR) }.to raise_error(ArgumentError)
        end
      end

      it "implies SEEK_SET with 1 argument" do
        BufferedFile.open(@filename, "rb") do |file|
          expect(file.read(8)).to eql DATA[0..7]
          expect(file.pos).to eql 8
          file.seek(4, IO::SEEK_CUR)
          expect(file.pos).to eql 12
          file.seek(0)
          expect(file.pos).to eql 0
        end
      end

      it "has reads still work afterwards" do
        BufferedFile.open(@filename, "rb") do |file|
          expect(file.read(8)).to eql DATA[0..7]
          expect(file.pos).to eql 8
          file.seek(4, IO::SEEK_CUR)
          expect(file.pos).to eql 12
          expect(file.read(1)).to eql DATA[12..12]
          expect(file.pos).to eql 13
          expect(file.read(3)).to eql DATA[13..15]
          expect(file.pos).to eql 16
          file.seek(0, IO::SEEK_SET)
          expect(file.pos).to eql 0
          expect(file.read(8)).to eql DATA[0..7]
          expect(file.pos).to eql 8
          file.seek(0, IO::SEEK_END)
          expect(file.pos).to eql (2 * BufferedFile::BUFFER_SIZE)
          file.seek(-16, IO::SEEK_END)
          expect(file.pos).to eql ((2 * BufferedFile::BUFFER_SIZE) - 16)
          expect(file.read(4)).to eql DATA[0..3]
          expect(file.pos).to eql ((2 * BufferedFile::BUFFER_SIZE) - 12)
          file.seek(4, IO::SEEK_CUR)
          expect(file.pos).to eql ((2 * BufferedFile::BUFFER_SIZE) - 8)
          file.seek(0, IO::SEEK_SET)
          expect(file.pos).to eql 0
          expect(file.read(8)).to eql DATA[0..7]
          expect(file.pos).to eql 8
          file.seek(4, IO::SEEK_CUR)
          expect(file.pos).to eql 12
          expect(file.read(1)).to eql DATA[12..12]
          expect(file.pos).to eql 13
          expect(file.read(3)).to eql DATA[13..15]
          expect(file.pos).to eql 16
        end
      end
    end
  end
end
