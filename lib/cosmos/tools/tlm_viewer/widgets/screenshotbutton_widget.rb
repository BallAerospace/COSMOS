# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos/tools/tlm_viewer/widgets/widget'
require 'cosmos/gui/utilities/screenshot'

module Cosmos
  # Creates a button that takes a screenshot of the screen it is on.
  # The output file location can be specified or by default it goes to
  # the system LOGS directory (output/logs)
  class ScreenshotbuttonWidget < Qt::PushButton
    include Widget

    def initialize (parent_layout, button_text = 'Screenshot', screenshot_directory = nil)
      super(nil, nil, nil, nil, button_text.to_s)
      if screenshot_directory
        @screenshot_directory = screenshot_directory
      else
        @screenshot_directory = System.paths['LOGS']
      end
      parent_layout.addWidget(self) if parent_layout
      connect(SIGNAL('clicked()')) do
        filename = File.join(@screenshot_directory, File.build_timestamped_filename([@screen.full_name], '.png'))
        Screenshot.screenshot_window(@screen.window, filename)
      end
    end
  end
end
