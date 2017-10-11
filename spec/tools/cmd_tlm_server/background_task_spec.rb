# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/tools/cmd_tlm_server/background_task'

module Cosmos
  describe BackgroundTask do
    describe "initialize" do
      it "initializes local variables" do
        b1 = BackgroundTask.new
        expect(b1.name).to match(/Background Task \d+/)
        expect(b1.thread).to be_nil
        expect(b1.status).to eq ''
        expect(b1.stopped).to eq false
        b2 = BackgroundTask.new
        expect(b2.name).to match(/Background Task \d+/)
        expect(b1.thread).to be_nil
        expect(b1.status).to eq ''
        expect(b2.stopped).to eq false
      end
    end

    describe "call" do
      it "raises an error" do
        expect { BackgroundTask.new.call }.to raise_error(/must be defined by subclass/)
      end
    end

    describe "stop" do
      it "exists" do
        expect(BackgroundTask.new).to respond_to(:stop)
      end
    end
  end
end
