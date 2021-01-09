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

module Cosmos
  describe ConfigureMicroservices do
    before(:each) do
      @redis = configure_store()
    end

    it "loads all the redis keys" do
      expect(@redis.exists('cosmos_scopes')).to eql(1)
      expect(@redis.exists('cosmos_microservices')).to eql(1)
      expect(@redis.exists('DEFAULT__cosmos_system')).to eql(1)
      expect(@redis.exists('DEFAULT__cosmos_targets')).to eql(1)
      expect(@redis.exists('DEFAULT__cosmoscmd__INST', 'DEFAULT__cosmoscmd__SYSTEM')).to eql(2)
      expect(@redis.exists('DEFAULT__cosmostlm__INST', 'DEFAULT__cosmostlm__SYSTEM')).to eql(2)

      targets = @redis.hgetall('DEFAULT__cosmos_targets')
      expect(targets.keys).to include('INST', 'SYSTEM')
    end
  end
end
