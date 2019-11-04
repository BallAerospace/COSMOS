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
    Cosmos::Logger.info("#{request_start_time.formatted}: query: #{request}")

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
      when 'RAW_MAX', 'RAW_MIN', 'RAW_AVG', 'RAW_STDDEV'
        value_type = ItemToDecomTableMapping::CONVERTED
        item_name_modifier = requested_value_type.split('_')[1].downcase
        raise "#{requested_value_type} value_type is not valid with NONE reduction" if reduction == :NONE
      when 'CONVERTED'
        value_type = ItemToDecomTableMapping::RAW
        item_name_modifier = ""
        raise "CONVERTED value_type is only valid with NONE reduction" if reduction != :NONE
      when 'CONVERTED_MAX', 'CONVERTED_MIN', 'CONVERTED_AVG', 'CONVERTED_STDDEV'
        value_type = ItemToDecomTableMapping::RAW
        item_name_modifier = requested_value_type.split('_')[1].downcase
        raise "#{requested_value_type} value_type is not valid with NONE reduction" if reduction == :NONE
      else
        raise "Unknown value_type: #{requested_value_type}"
      end

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

      meta_ids = request['meta_ids']
      meta_ids ||= []

      unless meta_ids.length > 0
        meta_filters = request['meta_filters']
        meta_filters ||= []

        if meta_filters.length > 0
          meta_ids = process_meta_filters(meta_filters, is_tlm, end_time)
        end
      end

      limit = request['limit'].to_i
      limit = 10000 if limit <= 0 or limit > 10000

      offset = request['offset'].to_i
      offset = 0 if offset < 0

      return query_decom_reduced(
        item[0], item[1], item[2],
        value_type, is_tlm,
        start_time, end_time,
        reduction, reduction_modifier,
        item_name_modifier, limit, offset, meta_ids)

    rescue Exception => error
      msg = "Query Error: #{error.message}"
      raise $!, msg, $!.backtrace
    end
  end

  # Gets the list of item names for a given packet
  #
  # @param target_name Target name
  # @param packet_name Packet name
  # @param is_tlm true or false
  # @return [Array<String>] Array of item names
  def item_names(target_name, packet_name, is_tlm = true)
    Cosmos::Logger.info("#{Time.now.formatted}: item_names")

    target = Target.where("name = ?", target_name).first
    raise "Target #{target_name} not found" unless target

    packet = Packet.where("target_id = ? and name = ? and is_tlm = ?", target.id, packet_name, is_tlm).first
    raise "Packet #{target_name} #{packet_name} not found" unless packet

    items = Item.where("packet_id = ?", packet.id).select("name")
    item_names = []
    items.each { |item| item_names << item.name }

    return item_names
  end

  # Returns status on the DART Database
  def dart_status
    start_time = Time.now
    Cosmos::Logger.info("#{start_time.formatted}: dart_status")
    result = {}
    status = Status.first

    # Ingest Status
    # ---------------
    # Last PacketLogEntry Id
    last_ple = PacketLogEntry.select("id").last
    if last_ple
      result[:LAST_PLE_ID] = last_ple.id
    else
      result[:LAST_PLE_ID] = -1
    end
    # Num PacketLogEntries Needing Decom state = 0
    result[:PLE_STATE_NEED_DECOM] = PacketLogEntry.where("decom_state = 0").count
    # Num PacketLogEntries Errored - state >= 3
    result[:PLE_STATE_ERROR] = PacketLogEntry.where("decom_state >= 3").count
    # First Time in Database
    sort_first_ple = PacketLogEntry.order("time ASC").select("time").first
    if sort_first_ple
      result[:PLE_FIRST_TIME_S] = sort_first_ple.time.tv_sec
      result[:PLE_FIRST_TIME_US] = sort_first_ple.time.tv_usec
    else
      result[:PLE_FIRST_TIME_S] = 0
      result[:PLE_FIRST_TIME_US] = 0
    end
    # Last Time in Database
    sort_last_ple = PacketLogEntry.order("time DESC").select("time").first
    if sort_last_ple
      result[:PLE_LAST_TIME_S] = sort_last_ple.time.tv_sec
      result[:PLE_LAST_TIME_US] = sort_last_ple.time.tv_usec
    else
      result[:PLE_LAST_TIME_S] = 0
      result[:PLE_LAST_TIME_US] = 0
    end

    # Decom Status
    # ---------------
    # Decom Count
    result[:DECOM_COUNT] = status.decom_count
    # Decom Errors
    result[:DECOM_ERROR_COUNT] = status.decom_error_count
    # Decom Message
    result[:DECOM_MESSAGE] = status.decom_message
    # Decom Message Time
    result[:DECOM_MESSAGE_TIME_S] = status.decom_message_time.tv_sec
    result[:DECOM_MESSAGE_TIME_US] = status.decom_message_time.tv_usec

    # Reduction Status
    # ---------------
    # Reduction Count
    result[:REDUCTION_COUNT] = status.reduction_count
    # Reduction Errors
    result[:REDUCTION_ERROR_COUNT] = status.reduction_error_count
    # Reduction Message
    result[:REDUCTION_MESSAGE] = status.reduction_message
    # Reduction Time
    result[:REDUCTION_MESSAGE_TIME_S] = status.reduction_message_time.tv_sec
    result[:REDUCTION_MESSAGE_TIME_US] = status.reduction_message_time.tv_usec

    # Storage
    # ---------------
    Cosmos.set_working_dir do
      # Size of outputs/dart/data folder
      result[:DART_DATA_BYTES] = Dir.glob(File.join(Cosmos::System.paths['DART_DATA'], '**', '*')).map{ |f| File.size(f) }.inject(:+)
      # Size of outputs/dart/logs folder
      result[:DART_LOGS_BYTES] = Dir.glob(File.join(Cosmos::System.paths['DART_LOGS'], '**', '*')).map{ |f| File.size(f) }.inject(:+)
    end
    # Size of SQL Database
    begin
      result[:DART_DATABASE_BYTES] = ActiveRecord::Base.connection.execute("select pg_database_size('#{ActiveRecord::Base.connection_config[:database]}');")[0]['pg_database_size']
    rescue
      result[:DART_DATABASE_BYTES] = -1
    end

    end_time = Time.now
    delta = end_time - start_time
    result[:DART_STATUS_SECONDS] = delta

    return result
  end

  def clear_errors
    time = Time.now
    Cosmos::Logger.info("#{time.formatted}: clear_errors")
    status = Status.first
    status.decom_error_count = 0
    status.decom_message = ''
    status.decom_message_time = time
    status.reduction_error_count = 0
    status.reduction_message = ''
    status.reduction_message_time = time
    status.save!

    return nil
  end

end
