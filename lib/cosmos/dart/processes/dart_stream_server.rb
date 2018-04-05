# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require File.expand_path('../../config/environment', __FILE__)
require 'dart_tcpip_server_interface'
require 'dart_logging'

Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new('dart_stream_server')

  dts = DartTcpipServerInterface.new
  dts.connect
  Cosmos::Logger.info("Dart Stream Server Started...")
  begin
    sleep(1) while true
  rescue Interrupt
    Cosmos::Logger.info("Dart Stream Server Closing...")
    dart_logging.stop
    exit(0)
  end
end
