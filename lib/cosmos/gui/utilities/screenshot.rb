# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  # Class to take screenshots of COSMOS windows
  class Screenshot

    # Take a screenshot of the given window
    def self.screenshot_window (window, filename)
      if !Kernel.is_windows?()
        # Delay for one second to allow any dialogs to fully clear first
        start_time = Time.now.sys
        while ((Time.now.sys - start_time) < 1.0)
          Qt::CoreApplication.processEvents(Qt::EventLoop::AllEvents, 1000)
        end
      end

      # Create a Pixmap to save the screenshot into
      pixmap = Qt::Pixmap::grabWidget(window)
      pixmap.save(filename)
      pixmap
    end
  end # class Screenshot

end # module Cosmos
