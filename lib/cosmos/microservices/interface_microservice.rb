# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/microservices/microservice'
require 'cosmos/models/interface_model'

module Cosmos
  class InterfaceCmdHandlerThread
    def initialize(interface, tlm, scope:)
      @interface = interface
      @tlm = tlm
      @scope = scope
    end

    def start
      @thread = Thread.new do
        begin
          run()
        rescue Exception => err
          Logger.error "#{@interface.name}: Command handler thread died: #{err.formatted}"
          retry # TODO: Better way to re-start this thread? Kill entire microservice and re-start?
        end
      end
    end

    def run
      Store.instance.receive_commands(@interface, scope: @scope) do |topic, msg_hash|
        # Check for a raw write to the interface
        if topic =~ /CMDINTERFACE/
          if msg_hash['connect']
            Logger.info "#{@interface.name}: Connect requested"
            @tlm.attempting()
          end
          if msg_hash['disconnect']
            Logger.info "#{@interface.name}: Disconnect requested"
            @tlm.disconnect(false)
          end
          if msg_hash['raw']
            Logger.info "#{@interface.name}: Write raw"
            @interface.write_raw(msg_hash['raw'])
          end
          if msg_hash['inject_tlm']
            Logger.info "#{@interface.name}: Inject telemetry"
            @tlm.inject_tlm(msg_hash)
          end
          next 'SUCCESS'
        end

        target_name = msg_hash['target_name']
        cmd_name = msg_hash['cmd_name']
        cmd_params = JSON.parse(msg_hash['cmd_params'])
        range_check = ConfigParser.handle_true_false(msg_hash['range_check'])
        raw = ConfigParser.handle_true_false(msg_hash['raw'])
        begin
          begin
            command = System.commands.build_cmd(target_name, cmd_name, cmd_params, range_check, raw)
          rescue => e
            Logger.error "#{@interface.name}: #{e.formatted}"
            next e.message
          end

          if ConfigParser.handle_true_false(msg_hash['hazardous_check'])
            hazardous, hazardous_description = System.commands.cmd_pkt_hazardous?(command)
            # Return back the error, description, and the formatted command
            # This allows the error handler to simply re-send the command
            # TODO: Should we set target_name, cmd_name, and cmd_params instead?
            next "HazardousError\n#{hazardous_description}\n#{System.commands.format(command)}" if hazardous
          end

          begin
            @interface.write(command)
            # TODO: Apparently build_cmd doesn't set received_count so figure it out here
            topic = "#{@scope}__COMMAND__#{command.target_name}__#{command.packet_name}"
            id, packet = Store.instance.read_topic_last(topic)
            count = packet ? packet["received_count"].to_i : 0

            msg_hash = { time: command.received_time.to_nsec_from_epoch,
                        target_name: command.target_name,
                        packet_name: command.packet_name,
                        received_count: count + 1,
                        buffer: command.buffer(false) }
            Store.instance.write_topic(topic, msg_hash)

            json_hash = {}
            command.sorted_items.each do |item|
              json_hash[item.name] = command.read_item(item, :RAW)
              json_hash[item.name + "__C"] = command.read_item(item, :CONVERTED) if item.write_conversion or item.states
              json_hash[item.name + "__F"] = command.read_item(item, :FORMATTED) if item.format_string
              json_hash[item.name + "__U"] = command.read_item(item, :WITH_UNITS) if item.units
            end
            msg_hash.delete("buffer")
            msg_hash['json_data'] = JSON.generate(json_hash.as_json)
            Store.instance.write_topic("#{@scope}__DECOMCMD__#{command.target_name}__#{command.packet_name}", msg_hash)
            Store.instance.set_interface(@interface, scope: @scope)

            # Update target
            target = System.targets[command.target_name]
            if target
              target.cmd_cnt += 1
              #Store.instance.set_target(target, scope: @scope)
            end

            'SUCCESS'
          rescue => e
            Logger.error "#{@interface.name}: #{e.formatted}"
            next e.message
          end
        rescue => e
          Logger.error "#{@interface.name}: #{e.formatted}"
          next e.message
        end
      end
    end
  end

  class InterfaceMicroservice < Microservice
    UNKNOWN_BYTES_TO_PRINT = 16

    def initialize(name)
      super(name)
      scope = name.split("__")[0]
      interface_name = name.split("__")[2]
      @interface = InterfaceModel.from_json(InterfaceModel.get(name: interface_name, scope: scope), scope: scope).build
      @interface.name = interface_name
      @config["target_names"].each do |target_name|
        @interface.target_names << target_name
        target = System.targets[target_name]
        target.interface = @interface
        #Store.instance.set_target(target, scope: @scope) if target
      end
      if @interface.connect_on_startup
        @interface.state = 'ATTEMPTING'
      else
        @interface.state = 'DISCONNECTED'
      end
      Store.instance.set_interface(@interface, initialize: true, scope: @scope)

      @interface_thread_sleeper = Sleeper.new
      @cancel_thread = false
      @connection_failed_messages = []
      @connection_lost_messages = []
      @mutex = Mutex.new
      @cmd_thread = InterfaceCmdHandlerThread.new(@interface, self, scope: @scope)
      @cmd_thread.start
    end

    # External method to be called by the InterfaceCmdHandlerThread to connect
    # Thus we just set the state and allow the run method to handle the action
    def attempting()
      @interface.state = 'ATTEMPTING'
      Store.instance.set_interface(@interface, initialize: true, scope: @scope)
    end

    def run
      begin
        if @interface.read_allowed?
          Logger.info "#{@interface.name}: Starting packet reading"
        else
          Logger.info "#{@interface.name}: Starting connection maintenance"
        end
        while true
          break if @cancel_thread
          case @interface.state
          when 'DISCONNECTED'
            # Just wait to see if we should connect later
            @interface_thread_sleeper.sleep(1)
          when 'ATTEMPTING'
            begin
              @mutex.synchronize do
                # We need to make sure connect is not called after stop() has been called
                connect() unless @cancel_thread
              end
            rescue Exception => connect_error
              handle_connection_failed(connect_error)
              break if @cancel_thread
            end
          when 'CONNECTED'
            if @interface.read_allowed?
              begin
                packet = @interface.read
                if packet
                  handle_packet(packet)
                else
                  Logger.info "#{@interface.name}: Clean disconnect (returned nil)"
                  # Don't reconnect on a clean disconnect because it's intentional
                  handle_connection_lost(reconnect: false)
                  break if @cancel_thread
                end
              rescue Exception => err
                handle_connection_lost(err)
                break if @cancel_thread
              end
            else
              @interface_thread_sleeper.sleep(1)
              handle_connection_lost() if !@interface.connected?
            end
          end
        end
      rescue Exception => error
        Logger.error "#{@interface.name}: Packet reading thread died: #{error.formatted}"
        Cosmos.handle_fatal_exception(error)
      end
      Store.instance.set_interface(@interface, scope: @scope)
      Logger.info "#{@interface.name}: Stopped packet reading"
    end

    def handle_packet(packet)
      Store.instance.set_interface(@interface, scope: @scope)
      packet.received_time = Time.now.sys unless packet.received_time

      if packet.stored
        # Stored telemetry does not update the current value table
        identified_packet = System.telemetry.identify_and_define_packet(packet, @target_names)
      else
        # Identify and update packet
        if packet.identified?
          begin
            # Preidentifed packet - place it into the current value table
            identified_packet = System.telemetry.update!(packet.target_name,
                                                          packet.packet_name,
                                                          packet.buffer)
          rescue RuntimeError
            # Packet identified but we don't know about it
            # Clear packet_name and target_name and try to identify
            Logger.warn "#{@interface.name}: Received unknown identified telemetry: #{packet.target_name} #{packet.packet_name}"
            packet.target_name = nil
            packet.packet_name = nil
            identified_packet = System.telemetry.identify!(packet.buffer,
                                                            @target_names)
          end
        else
          # Packet needs to be identified
          identified_packet = System.telemetry.identify!(packet.buffer,
                                                          @target_names)
        end
      end

      if identified_packet
        identified_packet.received_time = packet.received_time
        identified_packet.stored = packet.stored
        identified_packet.extra = packet.extra
          packet = identified_packet
      else
        unknown_packet = System.telemetry.update!('UNKNOWN', 'UNKNOWN', packet.buffer)
        unknown_packet.received_time = packet.received_time
        unknown_packet.stored = packet.stored
        unknown_packet.extra = packet.extra
        packet = unknown_packet
        data_length = packet.length
        string = "#{@interface.name}: Unknown #{data_length} byte packet starting: "
        num_bytes_to_print = [UNKNOWN_BYTES_TO_PRINT, data_length].min
        data_to_print = packet.buffer(false)[0..(num_bytes_to_print - 1)]
        data_to_print.each_byte do |byte|
          string << sprintf("%02X", byte)
        end
        Logger.error string
      end

      # Update target
      target = System.targets[packet.target_name]
      if target
        target.tlm_cnt += 1
        #Store.instance.set_target(target, scope: @scope)
      end

      # Write to stream
      packet.received_count += 1
      msg_hash = { time: packet.received_time.to_nsec_from_epoch,
                   stored: packet.stored,
                   target_name: packet.target_name,
                   packet_name: packet.packet_name,
                   received_count: packet.received_count,
                   buffer: packet.buffer(false) }
      Store.instance.write_topic("#{@scope}__TELEMETRY__#{packet.target_name}__#{packet.packet_name}", msg_hash)
    end

    def inject_tlm(hash)
      packet = System.telemetry.packet(hash['target_name'], hash['packet_name']).clone
      if hash['item_hash']
        JSON.parse(hash['item_hash']).each do |item, value|
          packet.write(item.to_s, value, hash['value_type'].to_sym)
        end
      end
      handle_packet(packet)
    end

    def handle_connection_failed(connect_error)
      Logger.error "#{@interface.name}: Connection Failed: #{connect_error.formatted(false, false)}"
      case connect_error
      when Interrupt
        Logger.info "#{@interface.name}: Closing from signal"
        @cancel_thread = true
      when Errno::ECONNREFUSED, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::ENOTSOCK, Errno::EHOSTUNREACH, IOError
        # Do not write an exception file for these extremely common cases
      else
        if RuntimeError === connect_error and (connect_error.message =~ /canceled/ or connect_error.message =~ /timeout/)
          # Do not write an exception file for these extremely common cases
        else
          Logger.error "#{@interface.name}: #{connect_error.formatted}"
          unless @connection_failed_messages.include?(connect_error.message)
            Cosmos.write_exception_file(connect_error)
            @connection_failed_messages << connect_error.message
          end
        end
      end
      disconnect() # Ensure we do a clean disconnect
    end

    def handle_connection_lost(err = nil, reconnect: true)
      if err
        Logger.info "#{@interface.name}: Connection Lost: #{err.formatted(false, false)}"
        case err
        when Interrupt
          Logger.info "#{@interface.name}: Closing from signal"
          @cancel_thread = true
        when Errno::ECONNABORTED, Errno::ECONNRESET, Errno::ETIMEDOUT, Errno::EBADF, Errno::ENOTSOCK, IOError
          # Do not write an exception file for these extremely common cases
        else
          Logger.error "#{@interface.name}: #{err.formatted}"
          unless @connection_lost_messages.include?(err.message)
            Cosmos.write_exception_file(err)
            @connection_lost_messages << err.message
          end
        end
      else
        Logger.info "#{@interface.name}: Connection Lost"
      end
      disconnect(reconnect) # Ensure we do a clean disconnect
    end

    def connect()
      Logger.info "#{@interface.name}: Connecting ..."
      @interface.connect
      @interface.state = 'CONNECTED'
      Store.instance.set_interface(@interface, scope: @scope)
      Logger.info "#{@interface.name}: Connection Success"
    end

    def disconnect(allow_reconnect = true)
      @interface.disconnect

      # If the interface is set to auto_reconnect then delay so the thread
      # can come back around and allow the interface a chance to reconnect.
      if allow_reconnect and @interface.auto_reconnect and @interface.state != 'DISCONNECTED'
        attempting()
        if !@cancel_thread
          @interface_thread_sleeper.sleep(@interface.reconnect_delay)
        end
      else
        @interface.state = 'DISCONNECTED'
        Store.instance.set_interface(@interface, scope: @scope)
      end
    end

    # Disconnect from the interface and stop the thread
    def stop
      @mutex.synchronize do
        # Need to make sure that @cancel_thread is set and the interface disconnected within
        # mutex to ensure that connect() is not called when we want to stop()
        @cancel_thread = true
        @interface_thread_sleeper.cancel
        @interface.disconnect
        @interface.state = 'DISCONNECTED'
        Store.instance.set_interface(@interface, scope: @scope)
      end
      Cosmos.kill_thread(self, @interface_thread) if @interface_thread and @interface_thread != Thread.current
    end

    def shutdown(sig = nil)
      stop()
      super()
    end

    def graceful_kill
      # Just to avoid warning
    end
  end
end

Cosmos::InterfaceMicroservice.run if __FILE__ == $0
