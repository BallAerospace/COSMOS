# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/stdout'

module Cosmos

  describe Stdout do

    describe "instance" do
      it "should return a single instance" do
        expect(Stdout.instance).to eq(Stdout.instance)
      end
    end

    describe "puts" do
      it "should write to STDOUT" do
        expect($stdout).to receive(:puts).with("TEST")
        Stdout.instance.puts("TEST")
      end
    end
  end
end

