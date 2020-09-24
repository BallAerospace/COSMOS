# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'

module Cosmos
  describe ConfigureMicroservices do
    before(:each) do
      @redis = configure_store()
    end

    it "loads all the redis keys" do
      expect(@redis.exists('cosmos_scopes')).to eql(1)
      expect(@redis.exists('cosmos_log_messages')).to eql(1)
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
