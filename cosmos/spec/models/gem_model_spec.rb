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
#
# This program may also be used under the terms of a commercial or
# enterprise edition license of COSMOS if purchased from the
# copyright holder

require 'spec_helper'
require 'cosmos/models/gem_model'
require 'tempfile'
require 'ostruct'

module Cosmos
  describe GemModel do
    before(:each) do
      @scope = "DEFAULT"
      @s3 = instance_double("Aws::S3::Client") # .as_null_object
      @list_result = OpenStruct.new
      @list_result.contents = [OpenStruct.new({ key: 'cosmos-test1.gem' }), OpenStruct.new({ key: 'cosmos-test2.gem' })]
      allow(@s3).to receive(:list_objects).and_return(@list_result)
      allow(@s3).to receive(:head_bucket).with(any_args)
      allow(@s3).to receive(:create_bucket)
      allow(Aws::S3::Client).to receive(:new).and_return(@s3)
    end

    describe "self.names" do
      it "returns a list of gem names" do
        expect(GemModel.names).to eql ["cosmos-test1.gem", "cosmos-test2.gem"]
      end
    end

    describe "self.get" do
      it "copies the gem to the local filesystem" do
        response_path = File.join(Dir.pwd, 'cosmos-test1.gem')
        expect(@s3).to receive(:get_object).with(bucket: 'gems', key: 'cosmos-test1.gem', response_target: response_path)
        path = GemModel.get(Dir.pwd, 'cosmos-test1.gem')
        expect(path).to eql response_path
      end
    end

    describe "self.put" do
      it "raises if the gem doesn't exist" do
        expect { GemModel.put('another.gem') }.to raise_error(/does not exist/)
      end

      it "installs the gem to the gem server" do
        tf = Tempfile.new("cosmos-test3.gem")
        tf.close
        expect(@s3).to receive(:put_object)
        GemModel.put(tf.path)
        tf.unlink
      end
    end

    describe "self.destroy" do
      it "removes the gem from the gem server" do
        expect(@s3).to receive(:delete_object).with(bucket: 'gems', key: 'cosmos-test1.gem')
        GemModel.destroy("cosmos-test1.gem")
      end
    end
  end
end
