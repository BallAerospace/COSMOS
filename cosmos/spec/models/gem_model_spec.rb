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
require 'cosmos/models/gem_model'
require 'tempfile'

module Cosmos
  describe GemModel do
    # self.names can't really be tested outside geminabox because
    # by the time you're done stubbing everything you're not really testing

    describe "self.get" do
      it "raises if the gem server can't be reached" do
        expect { GemModel.get(Dir.pwd, 'testgem') }.to raise_error(Errno::ECONNREFUSED)
        FileUtils.rm_f 'testgem'
      end

      it "copies the gem to the local filesystem" do
        expect(HTTPClient).to receive(:get_content).with(/test.gem/).and_return("This is a gem")
        path = GemModel.get(Dir.pwd, 'test.gem')
        expect(File.read(path)).to eql "This is a gem"
        FileUtils.rm_f path
      end
    end

    describe "self.put" do
      it "raises if the gem doesn't exist" do
        expect { GemModel.put('another.gem') }.to raise_error(/does not exist/)
      end

      it "raises if the gem server can't be reached" do
        tf = Tempfile.new("testgem")
        tf.close
        # Simply check for error ... for some reason we don't always get Errno::ECONNREFUSED
        expect { GemModel.put(tf.path) }.to raise_error(RuntimeError)
        tf.unlink
      end

      it "installs the gem to the gem server" do
        tf = Tempfile.new("testgem")
        tf.close
        status = double("status")
        expect(status).to receive(:success?).and_return(true)
        expect(Open3).to receive(:capture2e).with(/#{tf.path}/).and_return(["success", status])
        result = GemModel.put(tf.path)
        expect(result).to eql "success"
        tf.unlink
      end
    end

    describe "self.destroy" do
      it "removes the gem from the gem server" do
        tf = Tempfile.new("testgem")
        tf.close
        status = double("status")
        expect(status).to receive(:success?).and_return(true)
        expect(Open3).to receive(:capture2e).with(/gem yank my-awesome-gem -v 1.2.3.4/).and_return(["success", status])
        result = GemModel.destroy("my-awesome-gem-1.2.3.4.gem")
        expect(result).to eql "success"
        tf.unlink
      end
    end
  end
end
