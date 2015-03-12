#!/usr/bin/env ruby
# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'bundler/setup' unless ENV['COSMOS_DEVEL']
require 'cosmos'
require 'cosmos/tools/tlm_extractor/tlm_extractor'
Cosmos::TlmExtractor.run
