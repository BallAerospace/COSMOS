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
  require 'cosmos/gui/utilities/script_module_gui'

  module Cosmos
    describe Script do
      after(:all) do
        # Load the original scripting file over the script_module_gui
        load 'cosmos/script/scripting.rb'
      end

      def stub_null_object(constant)
        class_double(constant).tap do |double|
          stub_const(constant, double)
          allow(double).to receive(:new).and_return(double(constant).as_null_object)
          yield double if block_given?
        end
      end

      let!(:qt_module) do
        class_double('Qt').as_stubbed_const(:transfer_nested_constants => true).tap do |double|
          stub_const('Qt', double)
          stub_const('Qt::WindowTitleHint', double)
          stub_const('Qt::WindowSystemMenuHint', double)
          allow(double).to receive(:execute_in_main_thread).and_yield
          allow(double).to receive(:debug_level)
        end
        stub_null_object('Qt::Widget')
        stub_null_object('Qt::Dialog') do |double|
          instance = double("Qt::Dialog").as_null_object
          allow(instance).to receive(:exec).and_return 1 # break the loop by returning 1
          allow(double).to receive(:new).and_return(instance)
        end
        # Stub Accepted to be 1 to match the instance exec returning 1
        stub_const('Qt::Dialog::Accepted', 1)
        stub_null_object('Qt::VBoxLayout')
        stub_null_object('Qt::HBoxLayout')
        stub_null_object('Qt::Label')
        stub_null_object('Qt::PushButton')
      end

      describe "combo_box" do
        it "should not modify the inputs" do
          class_double('Cosmos::ComboboxChooser').as_stubbed_const.tap do |double|
            chooser = double("ComboboxChooser").as_null_object
            allow(chooser).to receive(:sel_command_callback=) do |args|
              # Simulate the user clicking the TEST option in the combobox
              args.call("TEST")
            end
            allow(double).to receive(:new).and_return(chooser)
          end

          buttons = %w(THIS IS A TEST)
          combo_box("HI", *buttons)
          expect(buttons).to eq %w(THIS IS A TEST)
        end
      end

      describe "message_box" do
        it "should not modify the inputs" do
          class_double('Qt::MessageBox').as_stubbed_const.tap do |double|
            msg_box = double("MessageBox").as_null_object
            allow(msg_box).to receive_message_chain(:clickedButton, :text).and_return("TEST")
            allow(double).to receive(:new).and_return(msg_box)
            stub_const('Qt::MessageBox::AcceptRole', 1)
            stub_const('Qt::MessageBox::RejectRole', 0)
          end

          buttons = %w(THIS IS A TEST)
          message_box("HI", *buttons)
          expect(buttons).to eq %w(THIS IS A TEST)
        end
      end

      describe "vertical_message_box" do
        it "should not modify the inputs" do
          stub_null_object('Qt::PushButton') do |double|
            instance = double("Qt::PushButton").as_null_object
            allow(instance).to receive(:connect).and_yield
            allow(double).to receive(:new).and_return(instance)
          end

          buttons = %w(THIS IS A TEST)
          vertical_message_box("HI", *buttons)
          expect(buttons).to eq %w(THIS IS A TEST)
        end
      end
    end
  end
end