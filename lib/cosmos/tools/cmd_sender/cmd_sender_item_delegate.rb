# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

module Cosmos

  class CmdSenderItemDelegate < Qt::StyledItemDelegate
    def initialize(parent)
      @table = parent
      super(parent)
    end

    def createEditor(parent, option, index)
      packet_item, _, _ = CmdSender.param_widgets[index.row]
      if index.column == 1 and packet_item and packet_item.states
        combo = Qt::ComboBox.new(parent)
        sorted_states = packet_item.states.sort {|a, b| a[1] <=> b[1]}
        items = sorted_states.map {|state_name, state_value| state_name}
        items << CmdSender::MANUALLY
        combo.addItems(items)
        combo.setCurrentText(@table.item(index.row, index.column).text.to_s)
        combo.setMaxVisibleItems(6)
        connect(combo, SIGNAL('activated(int)')) do
          emit commitData(combo)
          CmdSender.table.closeEditor(combo, 0)
        end
        return combo
      else
        return super(parent, option, index)
      end
    end

    def paint(painter, option, index)
      packet_item, _, _ = CmdSender.param_widgets[index.row]
      if index.column == 1 and packet_item and packet_item.states
        # This code simply draws the current combo box text inside a button to
        # give the user an idea that they have to click it to activate it
        opt = Qt::StyleOptionButton.new
        opt.rect = option.rect
        opt.text = @table.item(index.row, index.column).text.to_s
        Qt::Application.style.drawControl(Qt::Style::CE_PushButton, opt, painter)
        opt.dispose
      else
        super(painter, option, index)
      end
    end

    def setModelData(editor, model, index)
      if Qt::ComboBox === editor
        model.setData(index, Qt::Variant.new(editor.currentText), Qt::EditRole)
      else
        super(editor, model, index)
      end
    end

    def setEditorData(editor, index)
      if Qt::ComboBox === editor
        v = index.data(Qt::EditRole)
        combo_index = editor.findText(v.toString)
        if combo_index >= 0
          editor.setCurrentIndex(combo_index)
        else
          editor.setCurrentIndex(0)
        end
      else
        super(editor, index)
      end
    end
  end

end # module Cosmos
