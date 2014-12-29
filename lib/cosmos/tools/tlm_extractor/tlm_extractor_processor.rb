# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/tools/tlm_extractor/tlm_extractor_config'

module Cosmos

  class TlmExtractorProcessor

    attr_accessor :packet_log_reader

    def initialize
      @packet_log_reader = System.default_packet_log_reader.new
    end

    def process_batch(batch_name, input_filenames, output_dir, output_extension, config_filenames, time_start = nil, time_end = nil, &block)
      configs = []
      config_filenames.each_with_index do |config_filename, config_file_index|
        configs << TlmExtractorConfig.new(config_filename)
        base = File.basename(config_filename)
        extension = File.extname(base)
        filename_no_extension = base[0..-(extension.length + 1)]
        configs[-1].output_filename = File.join(output_dir, batch_name.gsub(' ', '_') + '_' + filename_no_extension.gsub(' ', '_') + output_extension)
      end
      process(input_filenames, configs, time_start, time_end, &block)
    end # def process_batch

    def process(input_filenames, configs, time_start = nil, time_end = nil)
      Cosmos.set_working_dir do
        # Set input filenames for each config and open the output file
        configs.each { |config| config.input_filenames = input_filenames; config.open_output_file }

        # Process each input file
        packet_count = 0
        input_filenames.each_with_index do |filename, input_file_index|
          file_size = File.size(filename).to_f
          yield input_file_index, packet_count, 0.0 if block_given?
          @packet_log_reader.each(filename, true, time_start, time_end) do |packet|
            configs.each { |config| config.process_packet(packet) }
            yield input_file_index, packet_count, (@packet_log_reader.bytes_read / file_size) if block_given? and packet_count % 100 == 0
            packet_count += 1
          end
          yield input_file_index, packet_count, 1.0 if block_given?
        end
      end # Cosmos.set_working_dir
    ensure
      configs.each { |config| config.close_output_file }
    end # def process

  end # class TlmExtractorProcessor

end # module Cosmos
