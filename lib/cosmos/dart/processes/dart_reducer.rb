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
require 'dart_reducer_manager'
require 'dart_logging'

# Start the DartReducer
Cosmos.catch_fatal_exception do
  DartCommon.handle_argv

  Cosmos::Logger.level = Cosmos::Logger::INFO
  dart_logging = DartLogging.new('dart_reducer')
  num_threads = ENV['DART_NUM_REDUCERS']
  num_threads ||= 5
  num_threads = num_threads.to_i
  drm = DartReducerManager.new(num_threads)
  drm.run
  dart_logging.stop
end
