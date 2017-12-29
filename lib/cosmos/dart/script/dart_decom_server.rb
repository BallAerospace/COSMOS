require File.expand_path('../../config/environment', __FILE__)
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

class DartDecomServer
  include DartCommon

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
      start_time = Time.at(start_time_sec, start_time_usec) if start_time_sec and start_time_usec
      end_time = Time.at(end_time_sec, end_time_usec) if end_time_sec and end_time_usec

      item = request['item']
      raise "Item \"#{item}\" invalid" if item.length != 3

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

      value_type = request['value_type'].to_s.upcase
      case value_type.upcase
      when 'RAW'
        not_value_type = ItemToDecomTableMapping::CONVERTED
        item_name_modifier = ""
        raise "RAW value_type is only valid with NONE reduction" if reduction != :NONE
      when 'RAW_MAX'
        not_value_type = ItemToDecomTableMapping::CONVERTED
        item_name_modifier = "max"
        raise "RAW_MAX value_type is not valid with NONE reduction" if reduction == :NONE
      when 'RAW_MIN'
        not_value_type = ItemToDecomTableMapping::CONVERTED
        item_name_modifier = "min"
        raise "RAW_MIN value_type is not valid with NONE reduction" if reduction == :NONE
      when 'RAW_AVG'
        not_value_type = ItemToDecomTableMapping::CONVERTED
        item_name_modifier = "avg"
        raise "RAW_AVG value_type is not valid with NONE reduction" if reduction == :NONE
      when 'CONVERTED'
        not_value_type = ItemToDecomTableMapping::RAW
        item_name_modifier = ""
        raise "CONVERTED value_type is only valid with NONE reduction" if reduction != :NONE
      when 'CONVERTED_MAX'
        not_value_type = ItemToDecomTableMapping::RAW
        item_name_modifier = "max"
        raise "CONVERTED_MAX value_type is not valid with NONE reduction" if reduction == :NONE
      when 'CONVERTED_MIN'
        not_value_type = ItemToDecomTableMapping::RAW
        item_name_modifier = "min"
        raise "CONVERTED_MIN value_type is not valid with NONE reduction" if reduction == :NONE
      when 'CONVERTED_AVG'
        not_value_type = ItemToDecomTableMapping::RAW
        item_name_modifier = "avg"
        raise "CONVERTED_AVG value_type is not valid with NONE reduction" if reduction == :NONE
      else
        raise "Unknown value_type: #{value_type}"
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
          raise "Unknown cmd_tlm value: #{cmd_tlm}"
        end
      else
        is_tlm = true
      end

      # Upon receiving the above request, the corresponding Target, Packet, and Item objects are requested from the database
      target_model = Target.where("name = ?", item[0]).first
      raise "Target: #{item[0]} not found" unless target_model
      packet_model = Packet.where("target_id = ? and name = ? and is_tlm = ?", target_model.id, item[1], is_tlm).first
      raise "Packet: #{item[1]} not found" unless packet_model
      item_model = Item.where("packet_id = ? and name = ?", packet_model.id, item[2]).first
      raise "Item: #{item[2]} not found" unless item_model

      # Then, the ItemToDecomTableMapping table is queried to find all entries that match the requested item, value_type, and reduction.
      # These entries are then filtered by requesting their correlated DecomTableMeta entries and eliminating tables that do not
      # contain data in the requested time range.
      packet_configs = PacketConfig.where("packet_id = ?", packet_model.id)
      packet_configs.where("start_time >= ?", start_time) if start_time
      packet_configs.where("end_time <= ?", end_time) if end_time
      packet_configs = packet_configs.order("start_time ASC")
      packet_config_ids = []
      packet_configs.each do |pc|
        packet_config_ids << pc.id
      end

      data = []
      mappings = ItemToDecomTableMapping.where("item_id = ? and value_type != ?", item_model.id, not_value_type).where("packet_config_id" => packet_config_ids)
      current_offset = 0
      current_count = 0
      mappings.each do |mapping|
        # Then, the actual values are queried from the correct T<X> tables with continued filtering by time range, and optional filtering
        # by meta_id.
        rows = get_decom_table_model(mapping.packet_config_id, mapping.table_index, reduction_modifier)

        if reduction == :NONE
          # For reduced data the time field is called start_time, for non-reduced it is just time
          rows = rows.where("time >= ?", start_time) if start_time
          rows = rows.where("time <= ?", end_time) if end_time
          rows = rows.where("meta_id" => meta_ids) if meta_ids.length > 0
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

Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new('dart_decom_server')

  json_drb = Cosmos::JsonDRb.new
  json_drb.acl = Cosmos::System.acl if Cosmos::System.acl
  begin
    json_drb.method_whitelist = ['query']
    begin
      json_drb.start_service(Cosmos::System.listen_hosts['DART_DECOM'], Cosmos::System.ports['DART_DECOM'], DartDecomServer.new)  # Cosmos::System.listen_hosts['DART_DECOM'], Cosmos::System.ports['DART_DECOM'], DartDecomServer.new)
    rescue Exception
      raise FatalError.new("Error starting JsonDRb on port #{Cosmos::System.ports['DART_DECOM']}.\nPerhaps another DART Decom Server is already running?")
    end
    ["TERM", "INT"].each {|sig| Signal.trap(sig) {exit}}
    Cosmos::Logger.info("Dart Decom Server Started...")
    sleep(1) while true
  rescue Interrupt
    Cosmos::Logger.info("Dart Decom Server Closing...")
    json_drb.stop_service
    dart_logging.stop
  end
end