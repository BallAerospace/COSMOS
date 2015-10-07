# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos/script'
require 'tempfile'

module Cosmos

  describe Script do

    before(:all) do
      cts = File.join(Cosmos::USERPATH,'config','tools','cmd_tlm_server','cmd_tlm_server.txt')
      FileUtils.mkdir_p(File.dirname(cts))
      File.open(cts,'w') do |file|
        file.puts 'INTERFACE INST_INT interface.rb'
        file.puts 'TARGET INST'
      end
      System.class_eval('@@instance = nil')
    end

    after(:all) do
      clean_config()
      FileUtils.rm_rf File.join(Cosmos::USERPATH,'config','tools')
    end

    describe "require cosmos/script.rb" do
      it "should require cosmos/script/script" do
        save = $0
        $0 = "Test"
        expect { load 'cosmos/script.rb' }.to_not raise_error()
        $0 = save
      end

      it "should raise when inside CmdTlmServer" do
        save = $0
        $0 = "CmdTlmServer"
        expect { load 'cosmos/script.rb' }.to raise_error(/must not be required/)
        $0 = save
      end

      it "should raise when inside Replay" do
        save = $0
        $0 = "Replay"
        expect { load 'cosmos/script.rb' }.to raise_error(/must not be required/)
        $0 = save
      end
    end

    describe "shutdown_cmd_tlm" do
      it "should call shutdown on the server" do
        set_cmd_tlm_disconnect(false)
        expect($cmd_tlm_server).to receive(:shutdown)
        shutdown_cmd_tlm()
      end

      it "should not call shutdown in disconnect mode" do
        set_cmd_tlm_disconnect(true)
        expect($cmd_tlm_server).to_not receive(:shutdown)
        shutdown_cmd_tlm()
        set_cmd_tlm_disconnect(false)
      end
    end

    describe "script_disconnect" do
      it "should disconnect from the server" do
        expect($cmd_tlm_server).to receive(:disconnect)
        script_disconnect()
      end
    end

    describe "set_cmd_tlm_disconnect and get_cmd_tlm_disconnect" do
      it "set and get the disconnect status" do
        set_cmd_tlm_disconnect(true)
        expect(get_cmd_tlm_disconnect()).to be true
        set_cmd_tlm_disconnect(false)
        expect(get_cmd_tlm_disconnect()).to be false
      end
    end

  end
end

