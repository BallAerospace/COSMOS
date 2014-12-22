# encoding: ascii-8bit

# Copyright © 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/io/stderr'

module Cosmos

  describe Stderr do

    describe "instance" do
      it "should return a single instance" do
        expect(Stderr.instance).to eq(Stderr.instance)
      end
    end

    describe "puts" do
      it "should write to STDERR" do
        expect($stderr).to receive(:puts).with("TEST")
        Stderr.instance.puts("TEST")
      end
    end
  end
end

