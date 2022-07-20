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
require 'openc3/script'
require 'tempfile'

module OpenC3
  describe Extract do
    before(:all) do
      setup_system()
      @packet = Packet.new("INST", "ASCIICMD")
      @packet.append_item('STRING', 2048, :STRING)
    end

    describe "add_cmd_parameter" do
      it "should remove quotes and preserve quoted strings" do
        cmd_params = {}
        add_cmd_parameter('TEST', '"3"', {}, cmd_params)
        expect(cmd_params['TEST']).to eql('3')
      end

      it "should convert unquoted strings to the correct value type" do
        cmd_params = {}
        add_cmd_parameter('TEST', '3', {}, cmd_params)
        expect(cmd_params['TEST']).to eql(3)
        add_cmd_parameter('TEST2', '3.0', {}, cmd_params)
        expect(cmd_params['TEST2']).to eql(3.0)
        add_cmd_parameter('TEST3', '0xA', {}, cmd_params)
        expect(cmd_params['TEST3']).to eql(0xA)
        add_cmd_parameter('TEST4', '3e3', {}, cmd_params)
        expect(cmd_params['TEST4']).to eql(3e3)
        add_cmd_parameter('TEST5', 'Ryan', {}, cmd_params)
        expect(cmd_params['TEST5']).to eql('Ryan')
        add_cmd_parameter('TEST6', '3 4', {}, cmd_params)
        expect(cmd_params['TEST6']).to eql('3 4')
      end

      it "should convert unquoted hex values into binary for blocks and strings" do
        cmd_params = {}
        add_cmd_parameter('STRING', '0xAABBCCDD', @packet.as_json(:allow_nan => true), cmd_params)
        expect(cmd_params['STRING']).to eql("\xAA\xBB\xCC\xDD")
      end

      it "should preserve quoted hex values for blocks and strings" do
        cmd_params = {}
        add_cmd_parameter('STRING', "'0xAABBCCDD'", @packet.as_json(:allow_nan => true), cmd_params)
        expect(cmd_params['STRING']).to eql("0xAABBCCDD")
      end
    end

    describe "extract_fields_from_cmd_text" do
      it "should complain about empty strings" do
        expect { extract_fields_from_cmd_text("") }.to raise_error(/text must not be empty/)
      end

      it "should complain about strings that end in with but have no other text" do
        expect { extract_fields_from_cmd_text("TEST COMMAND with") }.to raise_error(/must be followed by parameters/)
        expect { extract_fields_from_cmd_text("TEST COMMAND with            ") }.to raise_error(/must be followed by parameters/)
      end

      it "should complain if target name or packet name are missing" do
        expect { extract_fields_from_cmd_text("TEST") }.to raise_error(/Both Target Name and Command Name must be given/)
      end

      it "should complain if there are too many words before with" do
        expect { extract_fields_from_cmd_text("TEST TEST TEST") }.to raise_error(/Only Target Name and Command Name must be given/)
      end

      it "should complain if any key value pairs are misformed" do
        expect { extract_fields_from_cmd_text("TEST TEST with KEY VALUE, KEY VALUE, VALUE") }.to raise_error(/Missing value for last command parameter/)
        expect { extract_fields_from_cmd_text("TEST TEST with KEY VALUE KEY VALUE") }.to raise_error(/Missing comma in command parameters/)
        expect { extract_fields_from_cmd_text("TEST TEST with KEY VALUE KEY, KEY VALUE") }.to raise_error(/Missing comma in command parameters/)
        expect { extract_fields_from_cmd_text("TEST TEST with KEY VALUE, KEY") }.to raise_error(/Missing value for last command parameter/)
      end

      it "should parse commands correctly" do
        expect(extract_fields_from_cmd_text("TARGET PACKET with KEY1 VALUE1, KEY2 2, KEY3 '3', KEY4 4.0")).to eql(
          ['TARGET', 'PACKET', { 'KEY1' => 'VALUE1', 'KEY2' => 2, 'KEY3' => '3', 'KEY4' => 4.0 }]
        )
      end

      it "should handle multiple array parameters" do
        expect(extract_fields_from_cmd_text("TARGET PACKET with KEY1 [1,2,3,4], KEY2 2, KEY3 '3', KEY4 [5, 6, 7, 8]")).to eql(
          ['TARGET', 'PACKET', { 'KEY1' => [1, 2, 3, 4], 'KEY2' => 2, 'KEY3' => '3', 'KEY4' => [5, 6, 7, 8] }]
        )
        expect(extract_fields_from_cmd_text("TARGET PACKET with KEY1 [1,2,3,4], KEY2 2, KEY3 '3', KEY4 ['1', '2', '3', '4']")).to eql(
          ['TARGET', 'PACKET', { 'KEY1' => [1, 2, 3, 4], 'KEY2' => 2, 'KEY3' => '3', 'KEY4' => ['1', '2', '3', '4'] }]
        )
      end
    end

    describe "extract_fields_from_tlm_text" do
      it "should require exactly TARGET_NAME PACKET_NAME ITEM_NAME" do
        expect { extract_fields_from_tlm_text("") }.to raise_error(/Telemetry Item must be specified as/)
        expect { extract_fields_from_tlm_text("TARGET") }.to raise_error(/Telemetry Item must be specified as/)
        expect { extract_fields_from_tlm_text("TARGET PACKET") }.to raise_error(/Telemetry Item must be specified as/)
        expect { extract_fields_from_tlm_text("TARGET PACKET         ") }.to raise_error(/Telemetry Item must be specified as/)
        expect { extract_fields_from_tlm_text("TARGET PACKET ITEM OTHER") }.to raise_error(/Telemetry Item must be specified as/)
      end

      it "should parse telemetry names correctly" do
        expect(extract_fields_from_tlm_text("TARGET PACKET ITEM")).to eql(['TARGET', 'PACKET', 'ITEM'])
        expect(extract_fields_from_tlm_text("        TARGET         PACKET       ITEM        ")).to eql(['TARGET', 'PACKET', 'ITEM'])
      end
    end

    describe "extract_fields_from_set_tlm_text" do
      it "should complain if formatted incorrectly" do
        expect { extract_fields_from_set_tlm_text("") }.to raise_error(/Set Telemetry Item must be specified as/)
        expect { extract_fields_from_set_tlm_text("TARGET") }.to raise_error(/Set Telemetry Item must be specified as/)
        expect { extract_fields_from_set_tlm_text("TARGET PACKET") }.to raise_error(/Set Telemetry Item must be specified as/)
        expect { extract_fields_from_set_tlm_text("TARGET PACKET ITEM") }.to raise_error(/Set Telemetry Item must be specified as/)
        expect { extract_fields_from_set_tlm_text("TARGET PACKET ITEM=") }.to raise_error(/Set Telemetry Item must be specified as/)
        expect { extract_fields_from_set_tlm_text("TARGET PACKET ITEM=      ") }.to raise_error(/Set Telemetry Item must be specified as/)
        expect { extract_fields_from_set_tlm_text("TARGET PACKET ITEM =") }.to raise_error(/Set Telemetry Item must be specified as/)
        expect { extract_fields_from_set_tlm_text("TARGET PACKET ITEM =     ") }.to raise_error(/Set Telemetry Item must be specified as/)
      end

      it "should parse set_tlm text correctly" do
        expect(extract_fields_from_set_tlm_text("TARGET PACKET ITEM= 5")).to eql(['TARGET', 'PACKET', 'ITEM', 5])
        expect(extract_fields_from_set_tlm_text("TARGET PACKET ITEM = 5")).to eql(['TARGET', 'PACKET', 'ITEM', 5])
        expect(extract_fields_from_set_tlm_text("TARGET PACKET ITEM =5")).to eql(['TARGET', 'PACKET', 'ITEM', 5])
        expect(extract_fields_from_set_tlm_text("TARGET PACKET ITEM=5")).to eql(['TARGET', 'PACKET', 'ITEM', 5])
        expect(extract_fields_from_set_tlm_text("TARGET PACKET ITEM = 5.0")).to eql(['TARGET', 'PACKET', 'ITEM', 5.0])
        expect(extract_fields_from_set_tlm_text("TARGET PACKET ITEM = Ryan")).to eql(['TARGET', 'PACKET', 'ITEM', 'Ryan'])
        expect(extract_fields_from_set_tlm_text("TARGET PACKET ITEM = [1,2,3]")).to eql(['TARGET', 'PACKET', 'ITEM', [1, 2, 3]])
      end
    end

    describe "extract_fields_from_check_text" do
      it "should complain if formatted incorrectly" do
        expect { extract_fields_from_check_text("") }.to raise_error(/Check improperly specified/)
        expect { extract_fields_from_check_text("TARGET") }.to raise_error(/Check improperly specified/)
        expect { extract_fields_from_check_text("TARGET PACKET") }.to raise_error(/Check improperly specified/)
      end

      it "should support no comparison" do
        expect(extract_fields_from_check_text("TARGET PACKET ITEM")).to eql(['TARGET', 'PACKET', 'ITEM', nil])
        expect(extract_fields_from_check_text("TARGET PACKET ITEM             ")).to eql(['TARGET', 'PACKET', 'ITEM', nil])
      end

      it "should support comparisons" do
        expect(extract_fields_from_check_text("TARGET PACKET ITEM == 5")).to eql(['TARGET', 'PACKET', 'ITEM', '== 5'])
        expect(extract_fields_from_check_text("TARGET PACKET ITEM > 5")).to eql(['TARGET', 'PACKET', 'ITEM', '> 5'])
        expect(extract_fields_from_check_text("TARGET PACKET ITEM < 5")).to eql(['TARGET', 'PACKET', 'ITEM', '< 5'])
      end

      it "should support target packet items named the same" do
        expect(extract_fields_from_check_text("TEST TEST TEST == 5")).to eql(['TEST', 'TEST', 'TEST', '== 5'])
      end

      it "should complain about trying to do an = comparison" do
        expect { extract_fields_from_check_text("TARGET PACKET ITEM = 5") }.to raise_error(/ERROR: Use/)
      end

      it "should handle spaces throughout correctly" do
        expect(extract_fields_from_check_text("TARGET PACKET ITEM == \"This   is  a test\"")).to eql(['TARGET', 'PACKET', 'ITEM', "== \"This   is  a test\""])
        expect(extract_fields_from_check_text("TARGET   PACKET  ITEM   ==    'This is  a test   '")).to eql(['TARGET', 'PACKET', 'ITEM', "  ==    'This is  a test   '"])
      end
    end
  end
end
