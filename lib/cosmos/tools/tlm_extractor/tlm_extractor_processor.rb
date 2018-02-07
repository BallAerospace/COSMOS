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
      @packet_log_reader = System.default_packet_log_reader.new(*System.default_packet_log_reader_params)
    end

    def process_batch(batch_name, input_filenames, output_dir, output_extension, config_filenames, time_start = nil, time_end = nil, &block)
      configs = []
      config_filenames.each_with_index do |config_filename, config_file_index|
        configs << TlmExtractorConfig.new(config_filename)
        base = File.basename(config_filename)
        extension = File.extname(base)
        filename_no_extension = base[0..-(extension.length + 1)]
        configs[-1].output_filename = File.join(output_dir, batch_name.tr(' ', '_') + '_' + filename_no_extension.tr(' ', '_') + output_extension)
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

    def process_dart_batch(batch_name, output_dir, output_extension, config_filenames, time_start = nil, time_end = nil, &block)
      configs = []
      config_filenames.each_with_index do |config_filename, config_file_index|
        configs << TlmExtractorConfig.new(config_filename)
        base = File.basename(config_filename)
        extension = File.extname(base)
        filename_no_extension = base[0..-(extension.length + 1)]
        configs[-1].output_filename = File.join(output_dir, batch_name.tr(' ', '_') + '_' + filename_no_extension.tr(' ', '_') + output_extension)
      end
      process_dart(configs, time_start, time_end, &block)
    end

    def process_dart(configs, time_start = nil, time_end = nil)
      Cosmos.set_working_dir do
        items = []
        configs.each { |config| config.mode = :dart; items.concat(config.normal_items); config.open_output_file }
        items.uniq!
 
        time_start = Time.utc(1970, 1, 1) unless time_start
        time_end = Time.now unless time_end

        results = {}
        server = JsonDRbObject.new(System.connect_hosts['DART_DECOM'], System.ports['DART_DECOM'])

        index = 0
        items.each do |item_type, target_name, packet_name, item_name, value_type|
          value_type = :CONVERTED if !value_type or value_type != :RAW
          # TODO: Support FORMATTED and WITH_UNITS by iterating and modifying results
          begin
            query_string = "#{target_name} #{packet_name} #{item_name} #{value_type}"
            yield(index.to_f / items.length, "Querying #{query_string}") if block_given?
            request = {}
            request['start_time_sec'] = time_start.tv_sec
            request['start_time_usec'] = time_start.tv_usec
            request['end_time_sec'] = time_end.tv_sec
            request['end_time_usec'] = time_end.tv_usec
            request['item'] = [target_name, packet_name, item_name]
            request['reduction'] = 'NONE'
            request['cmd_tlm'] = 'TLM'
            request['offset'] = 0
            request['limit'] = 10000
            request['value_type'] = value_type.to_s
            # request['meta_ids'] = [1, 1062642]
            result = server.query(request)
            results[query_string] = result
            index += 1
            yield(index.to_f / items.length, "  Received #{result.length} values") if block_given?
          rescue Exception => error
            yield(index.to_f / items.length, "Error querying #{query_string} : #{error.class}:#{error.message}\n#{error.backtrace.join("\n")}\n") if block_given?
            return # Bail out because something bad happened
          end          
        end

        configs.each { |config| config.process_dart(results) }
      end # Cosmos.set_working_dir
    ensure
      configs.each { |config| config.close_output_file }
    end

  end # class TlmExtractorProcessor

end # module Cosmos
