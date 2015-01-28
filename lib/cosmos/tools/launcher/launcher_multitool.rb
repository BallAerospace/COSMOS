# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'

module Cosmos

  class LauncherMultitool < Qt::Object
    slots 'button_clicked()'

    def initialize(parent, multitool_settings)
      super(parent)
      @multitool_settings = multitool_settings
    end

    def button_clicked
      @multitool_settings.each do |item_type, item, capture_io|
        case item_type
        when :TOOL
          if capture_io
            Cosmos.run_process_check_output(item)
          else
            Cosmos.run_process(item)
          end
        when :DELAY
          sleep(item)
        end
      end
    end
  end

end
