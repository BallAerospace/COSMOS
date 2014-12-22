# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'cosmos'
require 'cosmos/gui/qt'
require 'cosmos/gui/text/completion_text_edit'

module Cosmos

  class CompletionLineEdit < CompletionTextEdit
    def initialize(parent)
      super(parent)
      setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
      setVerticalScrollBarPolicy(Qt::ScrollBarAlwaysOff)
      setMaximumBlockCount(1)
      # Create a temporary LineEdit to figure out a good height
      line = Qt::LineEdit.new("ASDF99")
      setMaximumHeight(line.sizeHint.height)
      line.dispose
    end
  end

end # module Cosmos
