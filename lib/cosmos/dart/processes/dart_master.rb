# encoding: ascii-8bit

# Copyright 2018 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

ENV['RAILS_ENV'] = 'production'
require File.expand_path('../../config/environment', __FILE__)
require 'dart_common'
require 'dart_master_query'

ples_per_request = ENV['DART_PLE_REQ_SIZE']
ples_per_request ||= 5
ples_per_request = ples_per_request.to_i

Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new('dart_master')

  json_drb = Cosmos::JsonDRb.new
  json_drb.acl = Cosmos::System.acl if Cosmos::System.acl
  begin
    json_drb.method_whitelist = ['get_decom_ple_ids']
    begin
      json_drb.start_service(Cosmos::System.listen_hosts['DART_MASTER'],
        Cosmos::System.ports['DART_MASTER'], DartMasterQuery.new(ples_per_request))
    rescue Exception => error
      raise Cosmos::FatalError.new("Error starting JsonDRb on port #{Cosmos::System.ports['DART_MASTER']}.\nPerhaps another DART Master is already running?\n#{error.formatted}")
    end
    ["TERM", "INT"].each {|sig| Signal.trap(sig) {exit}}
    Cosmos::Logger.info("Dart Master Started...")
    sleep(1) while true
  rescue Interrupt
    Cosmos::Logger.info("Dart Master Closing...")
    json_drb.stop_service
    dart_logging.stop
  end
end
