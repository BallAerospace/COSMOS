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

require 'spec_helper'
require 'openc3/models/notification_model'

module OpenC3
  describe NotificationModel do
    describe "new" do
      it "returns a notification" do
        notification = NotificationModel.new(
          time: Time.now.to_nsec_from_epoch,
          severity: "INFO",
          url: "/tools/limitsmonitor",
          title: "test",
          body: "foobar"
        )
        expect(notification.time).not_to be_nil
        expect(notification.severity).to eql("INFO")
        expect(notification.url).to eql("/tools/limitsmonitor")
        expect(notification.title).to eql("test")
        expect(notification.body).to eql("foobar")
      end
    end

    describe "as_json" do
      it "returns a hash" do
        notification = NotificationModel.new(
          time: Time.now.to_nsec_from_epoch,
          severity: "INFO",
          url: "/tools/limitsmonitor",
          title: "test",
          body: "foobar"
        )
        hash = notification.as_json(:allow_nan => true)
        expect(hash["time"]).not_to be_nil
        expect(hash["severity"]).to eql("INFO")
        expect(hash["url"]).to eql("/tools/limitsmonitor")
        expect(hash["title"]).to eql("test")
        expect(hash["body"]).to eql("foobar")
      end
    end
  end
end
