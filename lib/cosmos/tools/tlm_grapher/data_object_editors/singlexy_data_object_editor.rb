# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation of the SinglexyDataObjectEditor class.   This class
# provides dialog box content to create/edit single x-y data objects.

require 'cosmos'
require 'cosmos/tools/tlm_grapher/data_object_editors/xy_data_object_editor'
require 'cosmos/tools/tlm_grapher/data_objects/singlexy_data_object'

module Cosmos

  # Widget which creates an editor for a single X-Y data object
  class SinglexyDataObjectEditor < XyDataObjectEditor

    def initialize(parent)
      super(parent)
      @data_object_class = SinglexyDataObject
    end

  end # class SinglexyDataObjectEditor

end # module Cosmos
