# encoding: ascii-8bit

# Copyright 2017 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

if RUBY_ENGINE == 'ruby' and !ENV['COSMOS_NO_EXT']
  require 'cosmos/ext/buffered_file'
else
  module Cosmos
    class BufferedFile < File
      BUFFER_SIZE = 16 * 1024

      # Initialize the BufferedFile.  Takes the same args as File
      def initialize(*args)
        super(*args)
        @buffer = ''
        @buffer_index = 0
      end

      # Read using an internal buffer to avoid system calls
      def read(read_length)
        if read_length <= (@buffer.length - @buffer_index)
          # Return part of the buffer without having to go to the OS
          result = @buffer[@buffer_index, read_length]
          @buffer_index += read_length
          return result
        elsif read_length > BUFFER_SIZE
          # Reading more than our buffer
          if @buffer.length > 0
            if @buffer_index > 0
              @buffer.slice!(0..(@buffer_index - 1))
              @buffer_index = 0
            end
            @buffer << super(read_length - @buffer.length).to_s
            return @buffer.slice!(0..-1)
          else
            return super(read_length)
          end
        else
          # Read into the buffer
          if @buffer_index > 0
            @buffer.slice!(0..(@buffer_index - 1))
            @buffer_index = 0
          end
          @buffer << super(BUFFER_SIZE - @buffer.length).to_s
          if @buffer.length <= 0
            return nil
          end

          if read_length <= @buffer.length
            result = @buffer[@buffer_index, read_length]
            @buffer_index += read_length
            return result
          else
            return @buffer.slice!(0..-1)
          end
        end
      end

      # Get the current file position
      def pos
        parent_pos = super()
        return parent_pos - (@buffer.length - @buffer_index)
      end

      # Seek to a given file position
      def seek(*args)
        case args.length
        when 1
          amount = args[0]
          whence = IO::SEEK_SET
        when 2
          amount = args[0]
          whence = args[1]
        else
          # Invalid number of arguments given - let super handle
          return super(*args)
        end

        if whence == IO::SEEK_CUR
          buffer_index = @buffer_index + amount
          if (buffer_index >= 0) && (buffer_index < @buffer.length)
            @buffer_index = buffer_index
            return 0
          end
          super(self.pos, IO::SEEK_SET)
        end

        @buffer.clear
        @buffer_index = 0
        return super(*args)
      end

    end
  end
end
