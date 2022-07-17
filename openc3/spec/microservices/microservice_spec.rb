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
require 'openc3/microservices/microservice'

# Override at_exit to do nothing for testing
saved_verbose = $VERBOSE; $VERBOSE = nil
def at_exit(*args, &block)
end
$VERBOSE = saved_verbose

module OpenC3
  describe Microservice do
    before(:all) do
      setup_system()
    end

    describe "self.run" do
      before(:each) do
        allow(MicroserviceModel).to receive(:get).and_return(nil)
        allow(MicroserviceStatusModel).to receive(:set).with(any_args)
      end

      it "expects SCOPE__TYPE__NAME parameter as ENV['OPENC3_MICROSERVICE_NAME']" do
        ENV.delete('OPENC3_MICROSERVICE_NAME')
        expect { Microservice.run }.to raise_error("Microservice must be named")
        ENV['OPENC3_MICROSERVICE_NAME'] = "DEFAULT"
        expect { Microservice.run }.to raise_error(/Name DEFAULT doesn't match convention/)
        ENV['OPENC3_MICROSERVICE_NAME'] = "DEFAULT_TYPE_NAME"
        expect { Microservice.run }.to raise_error(/Name DEFAULT_TYPE_NAME doesn't match convention/)
        ENV['OPENC3_MICROSERVICE_NAME'] = "DEFAULT__TYPE__NAME"
        Microservice.run
        sleep 0.1
      end
    end
  end
end
