# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'dart_common'
require 'dart_logging'

# Rails Json screws up COSMOS handling of Nan, etc.
require "active_support/core_ext/object/json"
module ActiveSupport
  module ToJsonWithActiveSupportEncoder # :nodoc:
    def to_json(options = nil)
      super(options)
    end
  end
end

# JsonDRb server which responds to queries for decommutated and reduced data
# from the database.
class DartDecomQuery
  include DartCommon

  # Returns data from the decommutated database tables including the reduced data tables.
  #
  # @param request [Hash] Request for data.
  #   The hash must contain the following items:
  #     start_time_sec => Start time in UTC seconds
  #     start_time_usec => Microseconds to add to start time
  #     end_time_sec => End time in UTC seconds
  #     end_time_usec => Microseconds to add to end time
  #     item => [target name, packet name, item name] Names are all strings
  #     reduction => "NONE", "MINUTE", "HOUR", "DAY" for how to reduce the data
  #     value_type => "RAW", "RAW_MAX", "RAW_MIN", "RAW_AVG",
  #       "CONVERTED", "CONVERTED_MAX", "CONVERTED_MIN", "CONVERTED_AVG"
  #
  #   The request can also contain the following optional items:
  #     meta_ids => Optional IDs related to the meta data you want to filter by. This requires
  #       making a separate request for the particular meta data in question and recording
  #       the returned meta_ids for use in a subsequent request.
  #     limit => Maximum number of data items to return, must be less than 10000
  #     offset => Offset into the data stream. Since the maximum number of values allowed
  #       is 10000, you can set the offset to 10000, then 20000, etc to get additional values.
  #       By default the offset is 0.
  #     cmd_tlm => Whether the item is a command or telemetry. Default is telemetry.
  # @return [Array<Array<String, Integer, Integer, Integer, Integer>>] Array of arrays containing
  #   the item name, item seconds, item microseconds, samples (always 1 for NONE reduction, varies
  #   for other reduction values), and meta_id.
  def query(request)
    request_start_time = Time.now
    Cosmos::Logger.info("#{request_start_time.formatted}: QUERY: #{request}")

    begin
      start_time_sec = request['start_time_sec']
      start_time_usec = request['start_time_usec']
      end_time_sec = request['end_time_sec']
      end_time_usec = request['end_time_usec']

      start_time = nil
      end_time = nil
      begin
        start_time = Time.at(start_time_sec, start_time_usec) if start_time_sec and start_time_usec
      rescue
        raise "Invalid start time: #{start_time_sec}, #{start_time_usec}"
      end
      begin
        end_time = Time.at(end_time_sec, end_time_usec) if end_time_sec and end_time_usec
      rescue
        raise "Invalid end time: #{end_time_sec}, #{end_time_usec}"
      end

      item = request['item']
      raise "Item \"#{item}\" invalid" if !item || item.length != 3

      reduction = request['reduction'].to_s.upcase
      case reduction
      when "", "NONE"
        reduction = :NONE
        reduction_modifier = ""
      when "MINUTE"
        reduction = :MINUTE
        reduction_modifier = "_m"
      when "HOUR"
        reduction = :HOUR
        reduction_modifier = "_h"
      when "DAY"
        reduction = :DAY
        reduction_modifier = "_d"
      else
        raise "Unknown reduction: #{reduction}"
      end

      requested_value_type = request['value_type'].to_s.upcase
      case requested_value_type
      when 'RAW'
        value_type = ItemToDecomTableMapping::CONVERTED
        item_name_modifier = ""
        raise "RAW value_type is only valid with NONE reduction" if reduction != :NONE
      when 'RAW_MAX', 'RAW_MIN', 'RAW_AVG'
        value_type = ItemToDecomTableMapping::CONVERTED
        item_name_modifier = requested_value_type.split('_')[1].downcase
        raise "#{requested_value_type} value_type is not valid with NONE reduction" if reduction == :NONE
      when 'CONVERTED'
        value_type = ItemToDecomTableMapping::RAW
        item_name_modifier = ""
        raise "CONVERTED value_type is only valid with NONE reduction" if reduction != :NONE
      when 'CONVERTED_MAX', 'CONVERTED_MIN', 'CONVERTED_AVG'
        value_type = ItemToDecomTableMapping::RAW
        item_name_modifier = requested_value_type.split('_')[1].downcase
        raise "#{requested_value_type} value_type is not valid with NONE reduction" if reduction == :NONE
      else
        raise "Unknown value_type: #{requested_value_type}"
      end

      meta_ids = request['meta_ids']
      meta_ids ||= []

      limit = request['limit'].to_i
      limit = 10000 if limit <= 0 or limit > 10000

      offset = request['offset'].to_i
      offset = 0 if offset < 0

      cmd_tlm = request['cmd_tlm']
      if cmd_tlm
        if cmd_tlm.to_s.upcase == 'CMD'
          is_tlm = false
        elsif cmd_tlm.to_s.upcase == 'TLM'
          is_tlm = true
        else
          raise "Unknown cmd_tlm: #{cmd_tlm}"
        end
      else
        is_tlm = true
      end

      # Upon receiving the above request, the corresponding Target, Packet, and Item
      # objects are requested from the database
      target_model = Target.where("name = ?", item[0]).first
      raise "Target: #{item[0]} not found" unless target_model
      packet_model = Packet.where("target_id = ? and name = ? and is_tlm = ?", target_model.id, item[1], is_tlm).first
      raise "Packet: #{item[1]} not found" unless packet_model
      item_model = Item.where("packet_id = ? and name = ?", packet_model.id, item[2]).first
      raise "Item: #{item[2]} not found" unless item_model

      # Next the corresponding PacketConfigs are loaded within the requested times.
      # Note the PacketConfig time range covers when that particular packet configuration
      # was valid. Thus it can cover a much larger time period than the data requested.
      packet_configs = PacketConfig.where("packet_id = ?", packet_model.id)
      packet_configs.where("start_time >= ?", start_time) if start_time
      packet_configs.where("end_time <= ?", end_time) if end_time
      packet_configs = packet_configs.order("start_time ASC")
      packet_config_ids = []
      packet_configs.each do |pc|
        packet_config_ids << pc.id
      end

      # Then, the ItemToDecomTableMapping table is queried to find all entries that match
      # the requested item, value_type, and packet configuration. These entries represent
      # all the entries in the decommutation and reduction tables for the requested item
      # when that PacketConfig was valid.
      mappings = ItemToDecomTableMapping.where("item_id = ? and value_type != ?", item_model.id, value_type).where("packet_config_id" => packet_config_ids)
      data = []
      current_offset = 0
      current_count = 0
      mappings.each do |mapping|
        # The item to decommutation table entries are then used to access the actual
        # decommutation table model (ActiveRecord object).
        rows = get_decom_table_model(mapping.packet_config_id, mapping.table_index, reduction_modifier)

        # The decommutation table itself is then quered for the values with final filters on the requested
        # time range and optional filtering by meta_id. The correct decommutation table is selected by
        # using the passed in reduction value in the request.
        if reduction == :NONE
          # For reduced data the time field is called start_time, for non-reduced it is just time
          rows = rows.where("time >= ?", start_time) if start_time
          rows = rows.where("time <= ?", end_time) if end_time
          rows = rows.where("meta_id" => meta_ids) if meta_ids.length > 0
          # TODO - Add select call to filter down to just the columns needed
          rows.count
          rows.find_each do |row|
            data << [row.read_attribute("i#{mapping.item_index}"), row.time.tv_sec, row.time.tv_usec, 1, row.meta_id] unless current_offset < offset
            current_offset += 1
            current_count += 1
            break if current_count >= limit
          end
        elsif mapping.reduced
          # For reduced data the time field is called start_time, for non-reduced it is just time
          item_name = "i#{mapping.item_index}#{item_name_modifier}"
          rows = rows.where("start_time >= ?", start_time) if start_time
          rows = rows.where("start_time <= ?", end_time) if end_time
          rows = rows.where("meta_id" => meta_ids) if meta_ids.length > 0
          # TODO - Add select call to filter down to just the columns needed
          rows.find_each do |row|
            data << [row.read_attribute(item_name), row.start_time.tv_sec, row.start_time.tv_usec, row.num_samples, row.meta_id] unless current_offset < offset
            current_offset += 1
            current_count += 1
            break if current_count >= limit
          end
        end # else no data
      end

      return data
    rescue Exception => error
      msg = "Query Error: #{error.message}"
      raise $!, msg, $!.backtrace
    end
  end
end
