# encoding: ascii-8bit

# Copyright 2022 Ball Aerospace & Technologies Corp.
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

require 'socket'
require 'resolv'

# COSMOS specific additions to the Ruby Socket class
class Socket
  # @return [String] The IP address of the current machine
  def self.get_own_ip_address
    Resolv.getaddress Socket.gethostname
  end

  # @param ip_address [String] IP address in the form xxx.xxx.xxx.xxx
  # @return [String] The hostname of the given IP address or 'UNKNOWN' if the
  #   lookup fails
  def self.lookup_hostname_from_ip(ip_address)
    return Resolv.getname(ip_address)
  rescue
    return 'UNKNOWN'
  end
end
