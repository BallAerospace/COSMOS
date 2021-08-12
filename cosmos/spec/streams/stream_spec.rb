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
require 'cosmos/streams/stream'

module Cosmos
  describe Stream do
    describe "read, write, connected?, disconnect" do
      it "raises an error" do
        expect { Stream.new.read       }.to raise_error(/not defined/)
        expect { Stream.new.write(nil) }.to raise_error(/not defined/)
        expect { Stream.new.connect }.to raise_error(/not defined/)
        expect { Stream.new.connected? }.to raise_error(/not defined/)
        expect { Stream.new.disconnect }.to raise_error(/not defined/)
      end
    end
  end
end
