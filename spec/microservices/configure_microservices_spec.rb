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
      expect(@redis.exists('cosmos_system')).to eql(1)
      expect(@redis.exists('cosmos_targets')).to eql(1)
      expect(@redis.exists('cosmos_microservices')).to eql(1)
      expect(@redis.exists('cosmoscmd__INST', 'cosmoscmd__SYSTEM')).to eql(2)
      expect(@redis.exists('cosmostlm__INST', 'cosmostlm__SYSTEM')).to eql(2)

      targets = @redis.hgetall('cosmos_targets')
      expect(targets.keys).to include('INST', 'SYSTEM')
    end
  end
end
