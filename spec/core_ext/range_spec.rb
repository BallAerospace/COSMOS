# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/core_ext/range'

describe Range do

  describe "to_a_to_f" do
    it "should convert a Range to an array of floats" do
      (1..5).to_a_to_f.should eql [1.0,2.0,3.0,4.0,5.0]
    end
  end
end
