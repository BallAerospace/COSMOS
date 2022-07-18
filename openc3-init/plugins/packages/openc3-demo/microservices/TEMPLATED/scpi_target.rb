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
  class ScpiTarget
    class ScpiServerInterface < TcpipServerInterface
      def initialize(port)
        super(port.to_i, port.to_i, 5.0, nil, 'TERMINATED', '0xA', '0xA')
      end
    end

    class ScpiInterfaceThread < InterfaceThread
      def initialize(interface)
        super(interface)
        @index = 0
      end

      protected
      def handle_packet(packet)
        Logger.info "Received command: #{packet.buffer}"
        if packet.buffer.include?('?')
          @interface.write_raw(@index.to_s + "\x0A")
        end
        @index += 1
      end
    end

    def initialize(port)
      # Create interface to receive commands and send telemetry
      @target_interface = ScpiServerInterface.new(port)
      @interface_thread = nil
    end

    def start
      @interface_thread = ScpiInterfaceThread.new(@target_interface)
      @interface_thread.start
    end

    def stop
      @interface_thread.stop if @interface_thread
    end

    def self.run(target_name, port)
      Logger.level = Logger::INFO
      temp_dir = Dir.mktmpdir
      System.setup_targets([target_name], temp_dir, scope: ENV['OPENC3_SCOPE'])
      target = self.new(port)
      begin
        target.start
        loop { sleep 1 }
      rescue SystemExit, Interrupt
        target.stop
        FileUtils.remove_entry(temp_dir) if File.exist?(temp_dir)
      end
    end
  end
end

OpenC3::ScpiTarget.run(ARGV[0], ARGV[1]) if __FILE__ == $0
