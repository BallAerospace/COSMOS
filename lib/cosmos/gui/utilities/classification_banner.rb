# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module ClassificationBanner

  # Add to Qt::MainWindow the ability to display a classification banner. Typically used on every QtTool and Screen
  class Qt::MainWindow

    def add_classification_banner
      # Add a classification banner if the system configuration called for one
      classification_banner = Cosmos::System.instance.classificiation_banner
      unless classification_banner.nil?
        # Get the RGB color information from the classification_banner
        color_red   = classification_banner['color'].red
        color_green = classification_banner['color'].green
        color_blue  = classification_banner['color'].blue
        color_rgb   = "#{color_red},#{color_green},#{color_blue}"

        # Create a classification toolbar
        classification_toolbar = Qt::ToolBar.new
        # Disable right clicking on the bar (prevents it from being hidden unintentionally)
        classification_toolbar.setContextMenuPolicy(Qt::PreventContextMenu)
        # Freeze the bar at the top
        classification_toolbar.setFloatable(false)
        classification_toolbar.setMovable(false)
        # Specify sizes and set the style (background = background color, color = text color)
        classification_toolbar.minimumHeight = 20
        classification_toolbar.maximumHeight = 20
        classification_toolbar.setStyleSheet("background:rgb(#{color_rgb});color:white;text-align:center;border:none;")

        # Create a frame that will hold a horizontal layout
        label_frame = Qt::Frame.new
        label_layout = Qt::HBoxLayout.new(label_frame)
        label_layout.setContentsMargins(0,1,0,0) # Centers the text nicely inside the horizontal layout

        # Create a label of the classification and add it the horizontal layout
        label = Qt::Label.new("#{classification_banner['display_text']}")
        label.setStyleSheet("margin:0px;")

        # Add stretchers on either side so it is always in the middle and looks nice
        label_layout.addStretch(1)
        label_layout.addWidget(label)
        label_layout.addStretch(1)

        # Add the frame to the main toolbar, then add the toolbar to the MainWindow
        classification_toolbar.addWidget(label_frame)
        self.addToolBar(classification_toolbar)
      end

    end

  end
end
