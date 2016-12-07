# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/tools/table_manager/table_manager_core'

module Cosmos

  describe TableManagerCore do
    let(:core) { TableManagerCore.new }

    describe "reset" do
      it "clears the definition filename and configuration" do
        tf = Tempfile.new('unittest')
        tf.puts("TABLE table1 BIG_ENDIAN ONE_DIMENSIONAL")
        tf.close
        core.process_definition(tf.path)
        tf.unlink
        expect(core.definition_filename).to_not be_nil
        expect(core.config).to_not be_nil
        core.reset
        expect(core.definition_filename).to be_nil
        expect(core.config).to be_nil
      end
    end

  end # describe TableManagerCore
end

