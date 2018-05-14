# encoding: ascii-8bit

# Copyright 2014 Ball Aerospace & Technologies Corp.
# All Rights Reserved.
#
# This program is free software; you can modify and/or redistribute it
# under the terms of the GNU General Public License
# as published by the Free Software Foundation; version 3 with
# attribution addendums as found in the LICENSE.txt

require 'rails_helper'
require 'dart_importer'
require 'tempfile'
require 'cosmos/packet_logs/packet_log_writer'

describe DartImporter do
  before(:all) do
    @importer = DartImporter.new
    # Clean the system logs
    Dir["#{Cosmos::System.paths['LOGS']}/*"].each do |filename|
      FileUtils.rm_f filename
    end
  end

  before(:each) do
    DatabaseCleaner.strategy = :truncation
    DatabaseCleaner.clean
    Rails.application.load_seed
    # Clean the dart logs
    Dir["#{Cosmos::System.paths['DART_LOGS']}/*"].each do |filename|
      FileUtils.rm_f filename
    end
    @string_output = StringIO.new("", "r+")
    $stdout = @string_output
  end

  def create_dart_log_file
    plw = Cosmos::PacketLogWriter.new(:TLM,nil,true,nil,10000000,nil,false)
    packet = Cosmos::System.telemetry.packet("INST", "HEALTH_STATUS")
    plw.write(packet)
    plw.shutdown
    filename = File.expand_path(Dir[File.join(Cosmos::System.paths['LOGS'],"*.bin")][-1])
    FileUtils.mv(filename, Cosmos::System.paths['DART_DATA'])
    return File.expand_path(Dir[File.join(Cosmos::System.paths['DART_DATA'],"*.bin")][-1])
  end

  describe "import" do
    it "ensures file are in the DART_DATA dir" do
      tf = Tempfile.new('unittest')
      tf.puts "HI"
      tf.close
      code = @importer.import(tf, false)
      expect(code).to eq 1 # fail
      expect(@string_output.string).to match(/Imported files must be in \"#{File.expand_path(Cosmos::System.paths['DART_DATA'])}\"/)
      tf.unlink
    end

    it "checks that file can be opened by PacketLogReader" do
      filename = File.join(Cosmos::System.paths['DART_DATA'], "file.bin")
      File.open(filename, 'w') { |file| file.puts "HI" }
      code = @importer.import(filename, false)
      expect(code).to eq 1 # fail
      expect(@string_output.string).to match(/Unable to open/)
      FileUtils.rm_r filename
    end

    it "checks that file has packets" do
      filename = create_dart_log_file()
      allow_any_instance_of(Cosmos::PacketLogReader).to receive(:first).and_return(nil)
      code = @importer.import(filename, false)
      expect(code).to eq 1 # fail
      expect(@string_output.string).to match(/No packets found in file/)
      FileUtils.rm_r filename
    end

    it "warns about importing a file twice" do
      filename = create_dart_log_file()
      @importer.import(filename, false)
      expect(@string_output.string).to match(/Creating PacketLog entry/)
      @importer.import(filename, false)
      expect(@string_output.string).to match(/PacketLog already exists in database/)
    end
  end
end
