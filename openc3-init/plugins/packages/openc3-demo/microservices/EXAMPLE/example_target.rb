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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

require 'openc3'
require 'openc3/interfaces'
require 'openc3/tools/cmd_tlm_server/interface_thread'

module OpenC3
  class ExampleTarget
    class ExampleServerInterface < TcpipServerInterface
      def initialize(port)
        super(port.to_i, port.to_i, 5.0, nil, 'LENGTH', 0, 32, 4, 1, 'BIG_ENDIAN', 4, nil, nil, true)
      end
    end

    class ExampleInterfaceThread < InterfaceThread
      attr_accessor :target_name

      protected
      def handle_packet(packet)
        identified_packet = System.commands.identify(packet.buffer, [@target_name])
        if identified_packet
          Logger.info "Received command: #{identified_packet.target_name} #{identified_packet.packet_name}"
        else
          Logger.info "Received UNKNOWN command"
        end
      end
    end

    class ExampleTelemetryThread
      attr_reader :thread

      def initialize(interface, target_name)
        @interface = interface
        @target_name = target_name
        @sleeper = Sleeper.new
      end

      def start
        packet = System.telemetry.packet(@target_name, 'STATUS')
        @thread = Thread.new do
          @stop_thread = false
          @sleeper.sleep(5)
          begin
            loop do
              packet.write('PACKET_ID', 1)
              packet.write('STRING', "The time is now: #{Time.now.sys.formatted}")
              @interface.write(packet)
              break if @sleeper.sleep(1)
            end
          rescue Exception => err
            Logger.error "ExampleTelemetryThread unexpectedly died\n#{err.formatted}"
            raise err
          end
        end
      end

      def stop
        OpenC3.kill_thread(self, @thread)
      end

      def graceful_kill
        @sleeper.cancel
      end
    end

    def initialize(target_name, port)
      # Create interface to receive commands and send telemetry
      @target_name = target_name
      @interface = ExampleServerInterface.new(port)
      @interface_thread = nil
      @telemetry_thread = nil
    end

    def start
      @interface_thread = ExampleInterfaceThread.new(@interface)
      @interface_thread.target_name = @target_name
      @interface_thread.start
      @telemetry_thread = ExampleTelemetryThread.new(@interface, @target_name)
      @telemetry_thread.start
    end

    def stop
      @telemetry_thread.stop if @telemetry_thread
      @interface_thread.stop if @interface_thread
    end

    def self.run(target_name, port)
      Logger.level = Logger::INFO
      Thread.abort_on_exception = true
      temp_dir = Dir.mktmpdir
      System.setup_targets([target_name], temp_dir, scope: ENV['OPENC3_SCOPE'])
      target = self.new(target_name, port)
      begin
        target.start
        while true
          sleep 1
        end
      rescue SystemExit, Interrupt
        target.stop
        FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
      end
    end
  end
end

OpenC3::ExampleTarget.run(ARGV[0], ARGV[1]) if __FILE__ == $0
