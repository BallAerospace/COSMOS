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

# Modified by OpenC3, Inc.
# All changes Copyright 2022, OpenC3, Inc.
# All Rights Reserved

module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :uuid # , :token

    def connect
      # We don't have user accounts so use a random UUID
      self.uuid = SecureRandom.uuid
      # TODO: token? I saw some rails code using this
      # self.token = request.params[:token] ||
      #   request.cookies["token"] ||
      #   request.headers["X-API-TOKEN"]
    end
  end
end
