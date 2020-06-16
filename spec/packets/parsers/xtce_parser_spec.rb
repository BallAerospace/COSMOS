# encoding: ascii-8bit

# Copyright 2020 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'spec_helper'
require 'cosmos'
require 'cosmos/packets/packet_config'
require 'tempfile'

XTCE_START =<<END
<?xml version="1.0" encoding="UTF-8"?>
<xtce:SpaceSystem xmlns:xtce="http://www.omg.org/space/xtce" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" name="INST" xsi:schemaLocation="http://www.omg.org/space/xtce http://www.omg.org/spec/XTCE/20061101/06-11-06.xsd">
  <xtce:TelemetryMetaData>
    <xtce:ParameterTypeSet>
      <xtce:IntegerParameterType name="A_Type" shortDescription="A" signed="false">
        <xtce:UnitSet/>
END
XTCE_END =<<END
      </xtce:IntegerParameterType>
    </xtce:ParameterTypeSet>
    <xtce:ParameterSet>
      <xtce:Parameter name="A" parameterTypeRef="A_Type">
        <xtce:UnitSet/>
      </xtce:Parameter>
    </xtce:ParameterSet>
    <xtce:ContainerSet>
      <xtce:SequenceContainer name="B_Base" abstract="true">
        <xtce:EntryList>
          <xtce:ParameterRefEntry parameterRef="A"/>
        </xtce:EntryList>
      </xtce:SequenceContainer>
      <xtce:SequenceContainer name="B" shortDescription="B">
        <xtce:EntryList/>
        <xtce:BaseContainer containerRef="B_Base">
        </xtce:BaseContainer>
      </xtce:SequenceContainer>
    </xtce:ContainerSet>
  </xtce:TelemetryMetaData>
</xtce:SpaceSystem>
END

module Cosmos
  describe XtceParser do
    def xml_file(target)
      tf = Tempfile.new(['unittest', '.xtce'])
      tf.puts '<?xml version="1.0" encoding="UTF-8"?>'
      tf.puts "<xtce:SpaceSystem xmlns:xtce=\"http://www.omg.org/space/xtce\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" name=\"#{target}\" xsi:schemaLocation=\"http://www.omg.org/space/xtce http://www.omg.org/spec/XTCE/20061101/06-11-06.xsd\">"
      yield tf
      tf.puts '</xtce:SpaceSystem>'
      tf.close
      tf
    end

    def telemetry_file(target)
      file = xml_file(target) do |tf|
        tf.puts '  <xtce:TelemetryMetaData>'
        yield tf
        tf.puts '  </xtce:TelemetryMetaData>'
      end
      file
    end

    def add_tlm_packet_item(tf, packet, item)
      tf.puts "<xtce:ParameterTypeSet>"
      tf.puts "  <xtce:IntegerParameterType name=\"#{item}_Type\" shortDescription=\"#{item} Description\" signed=\"false\">"
      tf.puts "    <xtce:IntegerDataEncoding sizeInBits=\"8\" encoding=\"unsigned\"/>"
      yield tf
      tf.puts "  </xtce:IntegerParameterType>"
      tf.puts "</xtce:ParameterTypeSet>"
      tf.puts "<xtce:ParameterSet>"
      tf.puts "  <xtce:Parameter name=\"#{item}\" parameterTypeRef=\"#{item}_Type\"/>"
      tf.puts "</xtce:ParameterSet>"
      tf.puts "<xtce:ContainerSet>"
      tf.puts "  <xtce:SequenceContainer name=\"#{packet}_Base\" abstract=\"true\">"
      tf.puts "    <xtce:EntryList>"
      tf.puts "      <xtce:ParameterRefEntry parameterRef=\"#{item}\"/>"
      tf.puts "    </xtce:EntryList>"
      tf.puts "  </xtce:SequenceContainer>"
      tf.puts "  <xtce:SequenceContainer name=\"#{packet}\" shortDescription=\"Telemetry\">"
      tf.puts "    <xtce:EntryList/>"
      tf.puts "    <xtce:BaseContainer containerRef=\"#{packet}_Base\"/>"
      tf.puts "  </xtce:SequenceContainer>"
      tf.puts "</xtce:ContainerSet>"
    end

    def command_file(target)
      file = xml_file(target) do |tf|
        tf.puts '  <xtce:CommandMetaData>'
        yield tf
        tf.puts '  </xtce:CommandMetaData>'
      end
      file
    end

    def add_cmd_packet_item(tf, packet, item)
      tf.puts "<xtce:ArgumentTypeSet>"
      tf.puts "  <xtce:IntegerArgumentType name=\"#{item}_Type\" initialValue=\"0\" shortDescription=\"#{item} description\" signed=\"false\">"
      tf.puts "    <xtce:ByteOrderList>"
      tf.puts "      <xtce:Byte byteSignificance=\"0\"/>"
      tf.puts "      <xtce:Byte byteSignificance=\"1\"/>"
      tf.puts "    </xtce:ByteOrderList>"
      tf.puts "    <xtce:UnitSet/>"
      tf.puts "    <xtce:IntegerDataEncoding sizeInBits=\"16\" encoding=\"unsigned\"/>"
      tf.puts "    <xtce:ValidRange minInclusive=\"0\" maxInclusive=\"0\"/>"
      tf.puts "  </xtce:IntegerArgumentType>"
      tf.puts "</xtce:ArgumentTypeSet>"
      tf.puts "<xtce:MetaCommandSet>"
      tf.puts "  <xtce:MetaCommand name=\"#{packet}_Base\" abstract=\"true\">"
      tf.puts "    <xtce:ArgumentList>"
      tf.puts "      <xtce:Argument name=\"#{item}\" argumentTypeRef=\"#{item}_Type\"/>"
      tf.puts "    </xtce:ArgumentList>"
      tf.puts "    <xtce:CommandContainer name=\"#{packet}_CommandContainer\">"
      tf.puts "      <xtce:EntryList>"
      tf.puts "        <xtce:ArgumentRefEntry argumentRef=\"#{item}\"/>"
      tf.puts "      </xtce:EntryList>"
      tf.puts "    </xtce:CommandContainer>"
      tf.puts "  </xtce:MetaCommand>"
      tf.puts "  <xtce:MetaCommand name=\"#{packet}\" shortDescription=\"#{packet} description\">"
      tf.puts "    <xtce:BaseMetaCommand metaCommandRef=\"#{packet}_Base\"/>"
      tf.puts "  </xtce:MetaCommand>"
      tf.puts "</xtce:MetaCommandSet>"
    end

    describe "process_file" do
      before(:each) do
        configure_store()
        @pc = PacketConfig.new
      end

      it "processes xtce telemetry" do
        tf = Tempfile.new(['unittest', '.xtce'])
        tf.puts XTCE_START
        tf.puts '<xtce:IntegerDataEncoding sizeInBits="32" encoding="unsigned"/>'
        tf.puts XTCE_END
        tf.close

        @pc.process_file(tf.path, 'TEST')
        packet = @pc.telemetry['TEST']['B']
        expect(packet).to_not be_nil
        expect(packet.get_item('A').endianness).to eql :BIG_ENDIAN
        tf.unlink
      end

      it "processes xtce commands" do
        tf = command_file("TGT") do |file|
          add_cmd_packet_item(file, "PKT", "PARAM1")
        end

        @pc.process_file(tf.path, 'TGT')
        packet = @pc.commands['TGT']['PKT']
        expect(packet).to_not be_nil
        expect(packet.get_item('PARAM1').bit_offset).to eql 0
        expect(packet.get_item('PARAM1').bit_size).to eql 16
        expect(packet.get_item('PARAM1').data_type).to eql :UINT
        expect(packet.get_item('PARAM1').endianness).to eql :LITTLE_ENDIAN
        tf.unlink
      end

      context "with units" do
        it "processes description and value" do
          tf = telemetry_file("TGT") do |file|
            add_tlm_packet_item(file, "PKT", "TEMP1") do |file2|
              file2.puts '<xtce:UnitSet>'
              file2.puts '<xtce:Unit description="Volts">V</xtce:Unit>'
              file2.puts '</xtce:UnitSet>'
            end
          end

          @pc.process_file(tf.path, 'TGT')
          packet = @pc.telemetry['TGT']['PKT']
          expect(packet).to_not be_nil
          expect(packet.get_item('TEMP1').units).to eql 'V'
          expect(packet.get_item('TEMP1').units_full).to eql 'Volts'
          tf.unlink
        end

        it "processes description only" do
          tf = telemetry_file("TGT") do |file|
            add_tlm_packet_item(file, "PKT", "TEMP1") do |file2|
              file2.puts '<xtce:UnitSet>'
              file2.puts '<xtce:Unit description="Volts"/>'
              file2.puts '</xtce:UnitSet>'
            end
          end

          @pc.process_file(tf.path, 'TGT')
          packet = @pc.telemetry['TGT']['PKT']
          expect(packet).to_not be_nil
          expect(packet.get_item('TEMP1').units).to eql 'Volts'
          expect(packet.get_item('TEMP1').units_full).to eql 'Volts'
          tf.unlink
        end

        it "processes value only" do
          tf = telemetry_file("TGT") do |file|
            add_tlm_packet_item(file, "PKT", "TEMP1") do |file2|
              file2.puts '<xtce:UnitSet>'
              file2.puts '<xtce:Unit>V</xtce:Unit>'
              file2.puts '</xtce:UnitSet>'
            end
          end

          @pc.process_file(tf.path, 'TGT')
          packet = @pc.telemetry['TGT']['PKT']
          expect(packet).to_not be_nil
          expect(packet.get_item('TEMP1').units).to eql 'V'
          expect(packet.get_item('TEMP1').units_full).to eql 'V'
          tf.unlink
        end

        it "processes multiple units" do
          tf = telemetry_file("TGT") do |file|
            add_tlm_packet_item(file, "PKT", "TEMP1") do |file2|
              file2.puts '<xtce:UnitSet>'
              file2.puts '<xtce:Unit description="Volts">V</xtce:Unit>'
              file2.puts '<xtce:Unit description="Mega">M</xtce:Unit>'
              file2.puts '</xtce:UnitSet>'
            end
          end

          @pc.process_file(tf.path, 'TGT')
          packet = @pc.telemetry['TGT']['PKT']
          expect(packet).to_not be_nil
          expect(packet.get_item('TEMP1').units).to eql 'V/M'
          expect(packet.get_item('TEMP1').units_full).to eql 'Volts/Mega'
          tf.unlink
        end
      end

      it "processes explicit big endian xtce telemetry" do
        tf = Tempfile.new(['unittest', '.xtce'])
        tf.puts XTCE_START
        tf.puts '<xtce:IntegerDataEncoding sizeInBits="32" encoding="unsigned">' + "\n"
        tf.puts '  <xtce:ByteOrderList>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="3"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="2"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="1"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="0"/>' + "\n"
        tf.puts '  </xtce:ByteOrderList>' + "\n"
        tf.puts '</xtce:IntegerDataEncoding>' + "\n"
        tf.puts XTCE_END
        tf.close

        @pc.process_file(tf.path, 'TEST')

        packet = @pc.telemetry['TEST']['B']
        expect(packet).to_not be_nil
        expect(packet.get_item('A').endianness).to eql :BIG_ENDIAN
        expect(@pc.warnings).to be_empty

        tf.unlink
      end

      it "processes explicit little endian xtce telemetry" do
        tf = Tempfile.new(['unittest', '.xtce'])
        tf.puts XTCE_START
        tf.puts '<xtce:IntegerDataEncoding sizeInBits="32" encoding="unsigned">' + "\n"
        tf.puts '
        <xtce:ByteOrderList>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="0"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="1"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="2"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="3"/>' + "\n"
        tf.puts '  </xtce:ByteOrderList>' + "\n"
        tf.puts '</xtce:IntegerDataEncoding>' + "\n"
        tf.puts XTCE_END
        tf.close

        @pc.process_file(tf.path, 'TEST')

        packet = @pc.telemetry['TEST']['B']
        expect(packet).to_not be_nil
        expect(packet.get_item('A').endianness).to eql :LITTLE_ENDIAN
        expect(@pc.warnings).to be_empty

        tf.unlink
      end

      it "warns of bad byteorderlist no zero xtce telemetry" do
        tf = Tempfile.new(['unittest', '.xtce'])
        tf.puts XTCE_START
        tf.puts '<xtce:IntegerDataEncoding sizeInBits="32" encoding="unsigned">' + "\n"
        tf.puts '  <xtce:ByteOrderList>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="1"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="2"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="3"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="4"/>' + "\n"
        tf.puts '  </xtce:ByteOrderList>' + "\n"
        tf.puts '</xtce:IntegerDataEncoding>' + "\n"
        tf.puts XTCE_END
        tf.close

        @pc.process_file(tf.path, 'TEST')

        packet = @pc.telemetry['TEST']['B']
        expect(packet).to_not be_nil
        expect(packet.get_item('A').endianness).to eql :BIG_ENDIAN
        expect(@pc.warnings).to_not be_empty

        tf.unlink
      end

      it "warns of bad byteorderlist scrambled xtce telemetry" do
        tf = Tempfile.new(['unittest', '.xtce'])
        tf.puts XTCE_START
        tf.puts '<xtce:IntegerDataEncoding sizeInBits="32" encoding="unsigned">' + "\n"
        tf.puts '  <xtce:ByteOrderList>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="0"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="2"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="1"/>' + "\n"
        tf.puts '    <xtce:Byte byteSignificance="3"/>' + "\n"
        tf.puts '  </xtce:ByteOrderList>' + "\n"
        tf.puts '</xtce:IntegerDataEncoding>' + "\n"
        tf.puts XTCE_END
        tf.close

        @pc.process_file(tf.path, 'TEST')

        packet = @pc.telemetry['TEST']['B']
        expect(packet).to_not be_nil
        expect(packet.get_item('A').endianness).to eql :LITTLE_ENDIAN
        expect(@pc.warnings).to_not be_empty

        tf.unlink
      end

      it "outputs parsed definitions back to a file" do
        tf = Tempfile.new('unittest')
        cmd = "COMMAND TGT1 CMDPKT LITTLE_ENDIAN \"Command\"\n"\
              "  ID_PARAMETER CMD_OPCODE 0 16 UINT 0 0 0 \"Opcode\"\n"\
              "  PARAMETER CMD_UNSIGNED 16 16 UINT 0 65535 1 \"Unsigned\"\n"\
              "    STATE FALSE 0\n"\
              "    STATE TRUE 1\n"\
              "  PARAMETER CMD_SIGNED 32 16 INT -100 100 0 \"Signed\"\n"\
              "    UNITS Kilos K\n"\
              "  ARRAY_PARAMETER CMD_ARRAY 48 64 FLOAT 640 \"Array of 10 64bit floats\"\n"\
              "  PARAMETER CMD_FLOAT 688 32 FLOAT MIN MAX 10.0 \"Float\"\n"\
              "    POLY_WRITE_CONVERSION 10.0 0.5 0.25\n"\
              "  PARAMETER CMD_DOUBLE 720 64 FLOAT MIN MAX 0.0 \"Double\"\n"\
              "  PARAMETER CMD_STRING 784 32 STRING \"DEAD\" \"String\"\n"\
              "  PARAMETER CMD_STRING2 816 32 STRING 0xDEAD \"Binary\"\n"\
              "  PARAMETER CMD_BLOCK 848 32 BLOCK 0xBEEF \"Block\"\n"
        tf.puts cmd
        tlm1 = "TELEMETRY TGT1 TLMPKT BIG_ENDIAN \"Telemetry\"\n"\
               "  ID_ITEM TLM_OPCODE 0 8 UINT 1 \"Opcode\"\n"\
               "  ITEM UNSIGNED 8 8 UINT \"Unsigned\"\n"\
               "    STATE FALSE 0\n"\
               "    STATE TRUE 1\n"\
               "  ITEM SIGNED 16 8 INT \"Signed\"\n"\
               "    UNITS Kilos K\n"\
               "  ARRAY_ITEM ARRAY 24 8 UINT 80 \"Array\"\n"\
               "  ITEM FLOAT 104 32 FLOAT \"Float\"\n"\
               "    POLY_READ_CONVERSION 10.0 0.5 0.25\n"\
               "  ITEM DOUBLE 136 64 FLOAT \"Double\"\n"\
               "    LIMITS DEFAULT 1 ENABLED -80.0 -70.0 60.0 80.0\n"\
               "  ITEM STRING 200 32 STRING \"String\"\n"\
               "  ITEM BLOCK 232 32 BLOCK \"Block\"\n"\
               "  ITEM NOT_PACKED 300 8 UINT \"Not packed\"\n"
        tf.puts tlm1
        tlm2 = "TELEMETRY TGT1 TLMPKT2 BIG_ENDIAN \"Telemetry\"\n"\
               "  ID_ITEM TLM_OPCODE2 0 8 UINT 1 \"Opcode\"\n"\
               "  ITEM UNSIGNED2 8 32 UINT \"Little endian\" LITTLE_ENDIAN\n"\
               "    UNITS Kilos K\n"\
               "  ITEM SIGNED2 40 8 INT \"Signed\"\n"\
               "    LIMITS DEFAULT 1 ENABLED -80.0 -70.0 60.0 80.0\n"\
               "  ITEM SIGNED3 48 8 INT \"Signed3\"\n"
        tf.puts tlm2
        limits = "LIMITS_GROUP TVAC\n"\
                 "  LIMITS_GROUP_ITEM TGT1 TLMPKT UNSIGNED\n"
        tf.puts limits
        tf.close
        @pc.process_file(tf.path, "TGT1")
        @pc.to_xtce(Cosmos::USERPATH)
        xml_path = File.join(Cosmos::USERPATH, "TGT1", "cmd_tlm", "tgt1.xtce")
        expect(File.exist?(xml_path)).to be true
        @pc.process_file(xml_path, "TGT1")
        @pc.to_config(Cosmos::USERPATH)
        cmd_config_path = File.join(Cosmos::USERPATH, "TGT1", "cmd_tlm", "tgt1_cmd.txt")
        expect(File.read(cmd_config_path)).to include(cmd)
        tlm_config_path = File.join(Cosmos::USERPATH, "TGT1", "cmd_tlm", "tgt1_tlm.txt")
        tlm = File.read(tlm_config_path)
        expect(tlm).to include(tlm1)
        expect(tlm).to include(tlm2)
        tf.unlink
      end
    end
  end
end
