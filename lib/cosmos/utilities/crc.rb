# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/ext/crc'

module Cosmos

  # Abstract base class which {Crc16}, {Crc32} and {Crc64} use. Do NOT use this
  # class directly but instead use one of the subclasses.
  class Crc
    # @return [Integer] The polynomial used when calcuating the CRC
    attr_reader :poly
    # @return [Integer] Seed value used to start the calulation
    attr_reader :seed
    # @return [Boolean] Whether the result is XORed with 0xFFFF
    attr_reader :xor
    # @return [Boolean] Whether to bit reverse each byte
    attr_reader :reflect
    # @return [String] Binary lookup table used to perform the calculation
    attr_reader :table

    # Creates a CRC algorithm instance.
    #
    # @param poly [Integer] Polynomial to use when calculating the CRC
    # @param seed [Integer] Seed value to start the calculation
    # @param xor [Boolean] Whether to XOR the CRC result with 0xFFFF
    # @param reflect [Boolean] Whether to bit reverse each byte of data before
    #   calculating the CRC
    def initialize(poly, seed, xor, reflect)
      @poly = poly
      @seed = seed
      @xor = xor
      @reflect = reflect
      @table = ''

      # Determine which class we're using: Crc16, Crc32, Crc64
      digits = self.class.name[-2..-1].to_i
      case digits
      when 16
        pack = 'S'
      when 32
        pack = 'I'
      when 64
        pack = 'Q'
      end
      (0..255).each do |index|
        @table << [compute_table_entry(index, digits)].pack(pack)
      end
    end

    # @!method calc(data, seed = nil)
    #   Calculates the CRC across the data buffer using the optional seed.
    #   Implemented in C for speed.
    #
    #   @param data [String] String buffer of binary data to calculate a CRC on
    #   @param seed [Integer|nil] Seed value to start the calculation. Pass nil
    #     to use the default seed set in the constructor.
    #   @return [Integer] The CRC value

    protected

    # Compute a single entry in the crc lookup table
    def compute_table_entry(index, digits)
      # Start by shifting the index
      crc = index << (digits - 8)

      # The mask is 0x8000 for Crc16, 0x80000000 for Crc32, etc
      mask = (1 << (digits-1))

      8.times do
        if ((crc & mask) != 0)
          crc = (crc << 1) ^ @poly
        else
          crc = crc << 1
        end
      end

      # XOR the mask and or back in the top bit to get all ones
      mask = ~mask | mask
      return (crc & mask)
    end
  end

  # Calculates 16-bit CRCs over a buffer of data.
  class Crc16 < Crc
    # CRC-16-CCITT default polynomial
    DEFAULT_POLY = 0x1021
    # Seed for 16-bit CRC
    DEFAULT_SEED = 0xFFFF

    # Creates a 16 bit CRC algorithm instance. By default it is initialzed to
    # use the CRC-16-CCITT algorithm.
    #
    # @param poly [Integer] Polynomial to use when calculating the CRC
    # @param seed [Integer] Seed value to start the calculation
    # @param xor [Boolean] Whether to XOR the CRC result with 0xFFFF
    # @param reflect [Boolean] Whether to bit reverse each byte of data before
    #   calculating the CRC
    def initialize(poly = DEFAULT_POLY,
                   seed = DEFAULT_SEED,
                   xor  = false,
                   reflect = false)
      super(poly, seed, xor, reflect)
    end

    alias calculate_crc16 calc
  end # class Crc16

  # Calculates 32-bit CRCs over a buffer of data.
  class Crc32 < Crc
    # CRC-32 default polynomial
    DEFAULT_POLY = 0x04C11DB7
    # Default Seed for 32-bit CRC
    DEFAULT_SEED = 0xFFFFFFFF

    # Creates a 32 bit CRC algorithm instance. By default it is initialzed to
    # use the CRC-32 algorithm.
    #
    # @param poly [Integer] Polynomial to use when calculating the CRC
    # @param seed [Integer] Seed value to start the calculation
    # @param xor [Boolean] Whether to XOR the CRC result with 0xFFFF
    # @param reflect [Boolean] Whether to bit reverse each byte of data before
    #   calculating the CRC
    def initialize(poly = DEFAULT_POLY,
                   seed = DEFAULT_SEED,
                   xor = true,
                   reflect = true)
      super(poly, seed, xor, reflect)
    end

    alias calculate_crc32 calc
  end

  # Calculates 64-bit CRCs over a buffer of data.
  class Crc64 < Crc
    # CRC-64-ECMA default polynomial
    DEFAULT_POLY = 0x42F0E1EBA9EA3693
    # Default Seed for 64-bit CRC
    DEFAULT_SEED = 0xFFFFFFFFFFFFFFFF

    # Creates a 64 bit CRC algorithm instance. By default it is initialzed to
    # use the algorithm.
    #
    # @param poly [Integer] Polynomial to use when calculating the CRC
    # @param seed [Integer] Seed value to start the calculation
    # @param xor [Boolean] Whether to XOR the CRC result with 0xFFFF
    # @param reflect [Boolean] Whether to bit reverse each byte of data before
    #   calculating the CRC
    def initialize(poly = DEFAULT_POLY,
                   seed = DEFAULT_SEED,
                   xor = true,
                   reflect = true)
      super(poly, seed, xor, reflect)
    end

    alias calculate_crc64 calc
  end

end # module Cosmos
