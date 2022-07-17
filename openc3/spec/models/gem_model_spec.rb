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
require 'openc3/models/gem_model'
require 'tempfile'
require 'ostruct'

module OpenC3
  describe GemModel do
    before(:each) do
      @scope = "DEFAULT"
      @s3 = instance_double("Aws::S3::Client")
      @list_result = OpenStruct.new
      @list_result.contents = [OpenStruct.new({ key: 'openc3-test1.gem' }), OpenStruct.new({ key: 'openc3-test2.gem' })]
      allow(@s3).to receive(:list_objects).and_return(@list_result)
      allow(@s3).to receive(:head_bucket).with(any_args)
      allow(@s3).to receive(:create_bucket)
      allow(Aws::S3::Client).to receive(:new).and_return(@s3)
    end

    describe "self.names" do
      it "returns a list of gem names" do
        expect(GemModel.names).to eql ["openc3-test1.gem", "openc3-test2.gem"]
      end
    end

    describe "self.get" do
      it "copies the gem to the local filesystem" do
        response_path = File.join(Dir.pwd, 'openc3-test1.gem')
        expect(@s3).to receive(:get_object).with(bucket: 'gems', key: 'openc3-test1.gem', response_target: response_path)
        path = GemModel.get(Dir.pwd, 'openc3-test1.gem')
        expect(path).to eql response_path
      end
    end

    describe "self.put" do
      it "raises if the gem doesn't exist" do
        expect { GemModel.put('another.gem', scope: 'DEFAULT') }.to raise_error(/does not exist/)
      end

      it "installs the gem to the gem server" do
        pm = class_double("OpenC3::ProcessManager").as_stubbed_const(:transfer_nested_constants => true)
        expect(pm).to receive_message_chain(:instance, :spawn)
        tf = Tempfile.new("openc3-test3.gem")
        tf.close
        expect(@s3).to receive(:put_object).with(bucket: 'gems', key: File.basename(tf.path), body: anything)
        GemModel.put(tf.path, scope: 'DEFAULT')
        tf.unlink
      end
    end

    describe "self.destroy" do
      it "removes the gem from the gem server" do
        expect(@s3).to receive(:delete_object).with(bucket: 'gems', key: 'openc3-test1.gem')
        GemModel.destroy("openc3-test1.gem")
      end
    end
  end
end
