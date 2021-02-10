# encoding: ascii-8bit

# Copyright 2021 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU Affero General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/core_ext/objectspace'

describe ObjectSpace do

  if RUBY_ENGINE == 'ruby'
    describe "find" do
      it "finds a class in the Ruby object space" do
        expect(ObjectSpace.find(Class)).not_to be_nil
        expect(ObjectSpace.find(Cosmos)).to be_nil
      end
    end

    describe "find_all" do
      it "finds classes in the Ruby object space" do
        expect(ObjectSpace.find_all(Class)).to be_a(Array)
        expect(ObjectSpace.find_all(Cosmos)).to eql([])
      end
    end
  end

end
