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
require 'cosmos/core_ext/socket'

describe Socket do
  describe "get_own_ip_address" do
    it "returns the ip address of the current machine" do
      begin
        Socket.get_own_ip_address
        expect(Socket.get_own_ip_address).to match(/\b(?:\d{1,3}\.){3}\d{1,3}\b/)
      rescue Resolv::ResolvError
        # Oh well
      end
    end
  end

  describe "lookup_hostname_from_ip" do
    it "returns the hostname for the ip address" do
      if !ENV['APPVEYOR']
        ipaddr = Resolv.getaddress "localhost"
        expect(Socket.lookup_hostname_from_ip(ipaddr)).to_not be_nil
      end
    end
  end
end
