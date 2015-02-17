# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/streams/stream'

module Cosmos

  describe Stream do

    describe "read, write, connected?, disconnect" do
      it "should raise an error" do
        expect { Stream.new.read       }.to raise_error(/not defined/)
        expect { Stream.new.write(nil) }.to raise_error(/not defined/)
        expect { Stream.new.connect }.to raise_error(/not defined/)
        expect { Stream.new.connected? }.to raise_error(/not defined/)
        expect { Stream.new.disconnect }.to raise_error(/not defined/)
      end
    end

  end
end

