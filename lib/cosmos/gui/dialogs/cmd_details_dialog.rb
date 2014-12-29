# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

# This file contains the implementation and TlmDetailsDialog class.   This class
# is used to view a telemetry items settings typically on a right click.

require 'cosmos'
require 'cosmos/gui/dialogs/details_dialog'

module Cosmos

  class CmdDetailsDialog < DetailsDialog
    def initialize(parent, target_name, packet_name, item_name)
      super(parent, target_name, packet_name, item_name)

      begin
        packet = System.commands.packet(target_name, packet_name)
        item = packet.get_item(item_name)

        setWindowTitle("#{@target_name} #{@packet_name} #{@item_name} Details")

        layout = Qt::VBoxLayout.new
        layout.addWidget(Qt::Label.new("#{target_name} #{packet_name} #{item_name}"))

        # Display the parameter details
        item_details = Qt::GroupBox.new("Parameter Details")
        item_details.setLayout(build_details_layout(item, :CMD))
        layout.addWidget(item_details)

        # Add the OK button
        ok = Qt::PushButton.new("Ok")
        connect(ok, SIGNAL('clicked()'), self, SLOT('accept()'))
        layout.addWidget(ok)

        self.setLayout(layout)
        self.show
        self.raise
      rescue DRb::DRbConnError
        # Just do nothing
      end

    end
  end # class CmdDetailsDialog

end # module Cosmos
