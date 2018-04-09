# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'
require 'dart_decom_query'

Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new('dart_decom_server')

  json_drb = Cosmos::JsonDRb.new
  json_drb.acl = Cosmos::System.acl if Cosmos::System.acl
  begin
    json_drb.method_whitelist = ['query', 'item_names']
    begin
      json_drb.start_service(Cosmos::System.listen_hosts['DART_DECOM'],
        Cosmos::System.ports['DART_DECOM'], DartDecomQuery.new)
    rescue Exception
      raise Cosmos::FatalError.new("Error starting JsonDRb on port #{Cosmos::System.ports['DART_DECOM']}.\nPerhaps another DART Decom Server is already running?")
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
