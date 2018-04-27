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
require 'dart_logging'
require 'dart_decommutator'

Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  # 0-based worker ID
  worker_id = ARGV[0]
  worker_id ||= 0
  worker_id = worker_id.to_i
  # Total number of workers
  num_workers = ARGV[1]
  num_workers ||= 1
  num_workers = num_workers.to_i

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new("dart_worker_#{worker_id}")
  Cosmos::Logger.info("Dart Worker Starting...")
  raise "Worker count #{num_workers} invalid" if num_workers < 1
  raise "Worker id #{worker_id} too high for worker count of #{num_workers}" if worker_id >= num_workers
  decom = DartDecommutator.new(worker_id, num_workers)
  decom.run # Blocks forever
  shutdown_cmd_tlm()
  dart_logging.stop
end
