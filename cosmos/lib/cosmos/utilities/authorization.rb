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

begin
  require 'cosmos-enterprise/utilities/authorization'
  $cosmos_enterprise = true
rescue LoadError
  $cosmos_enterprise = false
end

$cosmos_authorize = false

module Cosmos

  class AuthError < StandardError
  end

  class ForbiddenError < StandardError
  end

  module Authorization

    private

    unless $cosmos_enterprise
      # Raises an exception if unauthorized, otherwise does nothing
      def authorize(permission: nil, target_name: nil, packet_name: nil, interface_name: nil, router_name: nil, scope: nil, token: nil)
        raise AuthError.new("Scope is required") unless scope
      end
    end

  end # module Authorization

end # module Cosmos
