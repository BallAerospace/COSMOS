# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

if RUBY_ENGINE == 'ruby'
  require 'spec_helper'
  require 'cosmos/gui/qt'
  require 'cosmos/script'
  require 'cosmos/script/scripting'

  module Cosmos
    describe Script do
      describe "combo_box" do
        it "should not modify the button inputs" do
          expect(self).to receive(:gets) { ' ' }
          capture_io do |stdout|
            buttons = %w(THIS IS A TEST)
            combo_box("Combo box test", *buttons)
            expect(buttons).to eq %w(THIS IS A TEST)
            expect(stdout.string).to match(/Combo box test/)
          end
        end

        it "should display details" do
          expect(self).to receive(:gets) { ' ' }
          capture_io do |stdout|
            buttons = %w(THIS IS A TEST)
            combo_box("HI", *buttons, details: 'These are the details')
            expect(stdout.string).to match(/These are the details/)
          end
        end
      end

      describe "message_box" do
        it "should not modify the inputs" do
          expect(self).to receive(:gets) { ' ' }
          capture_io do |stdout|
            buttons = %w(THIS IS A TEST)
            message_box("Message box test", *buttons)
            expect(buttons).to eq %w(THIS IS A TEST)
            expect(stdout.string).to match(/Message box test/)
          end
        end

        it "should display details" do
          expect(self).to receive(:gets) { ' ' }
          capture_io do |stdout|
            buttons = %w(THIS IS A TEST)
            message_box("HI", *buttons, details: 'These are the details')
            expect(stdout.string).to match(/These are the details/)
          end
        end
      end

      describe "vertical_message_box" do
        it "should not modify the inputs" do
          expect(self).to receive(:gets) { ' ' }
          capture_io do |stdout|
            buttons = %w(THIS IS A TEST)
            vertical_message_box("Vertical message box test", *buttons)
            expect(buttons).to eq %w(THIS IS A TEST)
            expect(stdout.string).to match(/Vertical message box test/)
          end
        end

        it "should display details" do
          expect(self).to receive(:gets) { ' ' }
          capture_io do |stdout|
            buttons = %w(THIS IS A TEST)
            vertical_message_box("HI", *buttons, details: 'These are the details')
            expect(stdout.string).to match(/These are the details/)
          end
        end
      end
    end
  end
end