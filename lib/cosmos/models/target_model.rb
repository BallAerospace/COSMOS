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

require 'cosmos/models/model'
require 'cosmos/system'
require 'cosmos/utilities/s3'
require 'zip'
require 'zip/filesystem'
require 'fileutils'
require 'tempfile'

module Cosmos
  class TargetModel < Model
    PRIMARY_KEY = 'cosmos_targets'
    VALID_TYPES = %i(CMD TLM)

    attr_accessor :folder_name
    attr_accessor :requires
    attr_accessor :ignored_parameters
    attr_accessor :ignored_items
    attr_accessor :cmd_tlm_files
    attr_accessor :cmd_unique_id_mode
    attr_accessor :tlm_unique_id_mode
    attr_accessor :id

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope: nil)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope: nil)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def self.all(scope: nil)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    # @return [Hash] Packet hash or raises an exception
    def self.packet(target_name, packet_name, type: :TLM, scope:)
      raise "Unknown type #{type} for #{target_name} #{packet_name}" unless VALID_TYPES.include?(type)
      # Assume it exists and just try to get it to avoid an extra call to Store.exist?
      json = Store.hget("#{scope}__cosmos#{type.to_s.downcase}__#{target_name}", packet_name)
      raise "Packet '#{target_name} #{packet_name}' does not exist" if json.nil?
      JSON.parse(json)
    end

    # @return [Array>Hash>] All packet hashes under the target_name
    def self.packets(target_name, type: :TLM, scope:)
      raise "Unknown type #{type} for #{target_name}" unless VALID_TYPES.include?(type)
      raise "Target '#{target_name}' does not exist" unless get(name: target_name, scope: scope)
      result = []
      packets = Store.hgetall("#{scope}__cosmos#{type.to_s.downcase}__#{target_name}")
      packets.sort.each do |packet_name, packet_json|
        result << JSON.parse(packet_json)
      end
      result
    end

    # @return [Hash] Item hash or raises an exception
    def self.packet_item(target_name, packet_name, item_name, type: :TLM, scope:)
      packet = packet(target_name, packet_name, type: type, scope: scope)
      item = packet['items'].find {|item| item['name'] == item_name.to_s }
      raise "Item '#{packet['target_name']} #{packet['packet_name']} #{item_name}' does not exist" unless item
      item
    end

    # @return [Array<Hash>] Item hash array or raises an exception
    def self.packet_items(target_name, packet_name, items, type: :TLM, scope:)
      packet = packet(target_name, packet_name, type: type, scope: scope)
      found = packet['items'].find_all {|item| items.map(&:to_s).include?(item['name']) }
      if found.length != items.length # we didn't find them all
        found_items = found.collect { |item| item['name'] }
        not_found = []
        (items - found_items).each do |item|
          not_found << "'#{target_name} #{packet_name} #{item}'"
        end
        # 'does not exist' not gramatically correct but we use it in every other exception
        raise "Item(s) #{not_found.join(', ')} does not exist"
      end
      found
    end

    # Called by the PluginModel to allow this class to validate it's top-level keyword: "TARGET"
    def self.handle_config(parser, keyword, parameters, plugin: nil, scope:)
      case keyword
      when 'TARGET'
        usage = "#{keyword} <TARGET FOLDER NAME> <TARGET NAME>"
        parser.verify_num_parameters(2, 2, usage)
        return self.new(name: parameters[1].to_s.upcase, folder_name: parameters[0].to_s.upcase, plugin: plugin, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Target: #{keyword} #{parameters.join(" ")}")
      end
    end

    def initialize(
      name:,
      folder_name:,
      requires: [],
      ignored_parameters: [],
      ignored_items: [],
      cmd_tlm_files: [],
      cmd_unique_id_mode: false,
      tlm_unique_id_mode: false,
      id: nil,
      updated_at: nil,
      plugin: nil,
      scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name, plugin: plugin, updated_at: updated_at, scope: scope)
      @folder_name = folder_name
      @requires = requires
      @ignored_parameters = ignored_parameters
      @ignored_items = ignored_items
      @cmd_tlm_files = cmd_tlm_files
      @cmd_unique_id_mode = cmd_unique_id_mode
      @tlm_unique_id_mode = tlm_unique_id_mode
      @id = id
    end

    def as_json
      {
        'name' => @name,
        'folder_name' => @folder_name,
        'requires' => @requires,
        'ignored_parameters' => @ignored_parameters,
        'ignored_items' => @ignored_items,
        'cmd_tlm_files' => @cmd_tlm_files,
        'cmd_unique_id_mode' => cmd_unique_id_mode,
        'tlm_unique_id_mode' => @tlm_unique_id_mode,
        'id' => @id,
        'updated_at' => @updated_at,
        'plugin' => @plugin
      }
    end

    def as_config
      "TARGET #{@folder_name} #{@name}\n"
    end

    def handle_config(parser, keyword, parameters)
      raise "Unsupported keyword for TARGET: #{keyword}"
    end

    def deploy(gem_path, variables)
      rubys3_client = Aws::S3::Client.new
      variables["target_name"] = @name
      start_path = "/targets/#{@folder_name}/"
      temp_dir = Dir.mktmpdir
      found = false
      begin
        target_path = gem_path + start_path + "**/*"
        Dir.glob(target_path) do |filename|
          next if filename == '.' or filename == '..' or File.directory?(filename)
          path = filename.split(gem_path)[-1]
          target_folder_path = path.split(start_path)[-1]
          key = "#{@scope}/targets/#{@name}/" + target_folder_path

          # Load target files
          data = File.read(filename, mode: "rb")
          data = ERB.new(data).result(binding.set_variables(variables)) if data.is_printable?
          local_path = File.join(temp_dir, @name, target_folder_path)
          FileUtils.mkdir_p(File.dirname(local_path))
          File.open(local_path, 'wb') {|file| file.write(data)}
          found = true
          rubys3_client.put_object(bucket: 'config', key: key, body: data)
        end
        raise "No target files found at #{target_path}" unless found

        target_folder = File.join(temp_dir, @name)
        build_target_archive(rubys3_client, temp_dir, target_folder)
        system = update_store(temp_dir)
        deploy_microservices(gem_path, variables, system)
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
      end
    end

    def undeploy
      rubys3_client = Aws::S3::Client.new
      prefix = "#{@scope}/targets/#{@name}/"
      rubys3_client.list_objects(bucket: 'config', prefix: prefix).contents.each do |object|
        rubys3_client.delete_object(bucket: 'config', key: object.key)
      end

      Store.del("#{@scope}__cosmostlm__#{@name}")
      Store.del("#{@scope}__cosmoscmd__#{@name}")

      model = MicroserviceModel.get_model(name: "#{@scope}__DECOM__#{@name}", scope: @scope)
      model.destroy if model
      model = MicroserviceModel.get_model(name: "#{@scope}__CVT__#{@name}", scope: @scope)
      model.destroy if model
      model = MicroserviceModel.get_model(name: "#{@scope}__PACKETLOG__#{@name}", scope: @scope)
      model.destroy if model
      model = MicroserviceModel.get_model(name: "#{@scope}__DECOMLOG__#{@name}", scope: @scope)
      model.destroy if model
    end

    ##################################################
    # The following methods are implementation details
    ##################################################

    def build_target_archive(rubys3_client, temp_dir, target_folder)
      target_files = []
      Find.find(target_folder) { |file| target_files << file }
      target_files.sort!
      hash = Cosmos.hash_files(target_files, nil, 'SHA256').hexdigest
      File.open(File.join(target_folder, 'target_id.txt'), 'wb') { |file| file.write(hash) }
      key = "#{@scope}/targets/#{@name}/target_id.txt"
      rubys3_client.put_object(bucket: 'config', key: key, body: hash)

      # Create target archive zip file
      prefix = File.dirname(target_folder) + '/'
      output_file = File.join(temp_dir, @name + '_' + hash + '.zip')
      Zip.continue_on_exists_proc = true
      Zip::File.open(output_file, Zip::File::CREATE) do |zipfile|
        target_files.each do |target_file|
          zip_file_path = target_file.delete_prefix(prefix)
          if File.directory?(target_file)
            zipfile.mkdir(zip_file_path)
          else
            zipfile.add(zip_file_path, target_file)
          end
        end
      end

      # Write Target Archive to S3 Bucket
      File.open(output_file, 'rb') do |file|
        s3_key = key = "#{@scope}/target_archives/#{@name}/#{@name}_current.zip"
        rubys3_client.put_object(bucket: 'config', key: s3_key, body: file)
      end
      File.open(output_file, 'rb') do |file|
        s3_key = key = "#{@scope}/target_archives/#{@name}/#{@name}_#{hash}.zip"
        rubys3_client.put_object(bucket: 'config', key: s3_key, body: file)
      end
    end

    def update_store(temp_dir)
      # Build a System for just this target
      system = System.new([@name], temp_dir)
      target = system.targets[@name]

      # Add in the information from the target and update
      @requires = target.requires
      @ignored_parameters = target.ignored_parameters
      @ignored_items = target.ignored_items
      @cmd_tlm_files = target.cmd_tlm_files
      @cmd_unique_id_mode = target.cmd_unique_id_mode
      @tlm_unique_id_mode = target.tlm_unique_id_mode
      @id = target.id
      update()

      # Store Packet Definitions
      system.telemetry.all.each do |target_name, packets|
        Store.del("#{@scope}__cosmostlm__#{target_name}")
        packets.each do |packet_name, packet|
          Logger.info "Configuring tlm packet: #{target_name} #{packet_name}"
          Store.hset("#{@scope}__cosmostlm__#{target_name}", packet_name, JSON.generate(packet.as_json))
        end
      end
      system.commands.all.each do |target_name, packets|
        Store.del("#{@scope}__cosmoscmd__#{target_name}")
        packets.each do |packet_name, packet|
          Logger.info "Configuring cmd packet: #{target_name} #{packet_name}"
          Store.hset("#{@scope}__cosmoscmd__#{target_name}", packet_name, JSON.generate(packet.as_json))
        end
      end
      # Store Limits Groups (which are already a Hash)
      Store.hset("#{@scope}__cosmos_system", 'limits_groups', JSON.generate(system.limits.groups))
      # Merge in Limits Sets
      sets = Store.hget("#{@scope}__cosmos_system", 'limits_sets')
      sets = JSON.parse(sets) if sets
      sets ||= []
      sets.concat(system.limits.sets.map(&:to_s)) # Convert the symbols to strings
      Store.hset("#{@scope}__cosmos_system", 'limits_sets', JSON.generate(sets.uniq)) # Ensure uniq set

      return system
    end

    def deploy_microservices(gem_path, variables, system)
      command_topic_list = []
      packet_topic_list = []
      decom_topic_list = []
      begin
        system.commands.packets(@name).each do |packet_name, packet|
          command_topic_list << "#{@scope}__COMMAND__#{@name}__#{packet_name}"
        end
      rescue
        # No command packets for this target
      end
      begin
        system.telemetry.packets(@name).each do |packet_name, packet|
          packet_topic_list << "#{@scope}__TELEMETRY__#{@name}__#{packet_name}"
          decom_topic_list << "#{@scope}__DECOM__#{@name}__#{packet_name}"
        end
      rescue
        # No telemetry packets for this target
      end
      # It's ok to call this with an empty array
      Store.initialize_streams(command_topic_list)
      # Might as well return if there are no packets
      return unless packet_topic_list.length > 0
      Store.initialize_streams(packet_topic_list)
      Store.initialize_streams(decom_topic_list)

      # Decom Microservice
      microservice_name = "#{@scope}__DECOM__#{@name}"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        folder_name: @folder_name,
        cmd: ["ruby", "decom_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        topics: packet_topic_list,
        target_names: [@name],
        plugin: plugin,
        scope: @scope)
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"

      microservice_name = "#{@scope}__CVT__#{@name}"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        folder_name: @folder_name,
        cmd: ["ruby", "cvt_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        topics: decom_topic_list,
        plugin: plugin,
        scope: @scope)
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"

      # PacketLog Microservice
      microservice_name = "#{@scope}__PACKETLOG__#{@name}"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        folder_name: @folder_name,
        cmd: ["ruby", "packet_log_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        topics: packet_topic_list,
        target_names: [@name],
        plugin: plugin,
        scope: @scope)
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"

      # DecomLog Microservice
      microservice_name = "#{@scope}__DECOMLOG__#{@name}"
      microservice = MicroserviceModel.new(
        name: microservice_name,
        folder_name: @folder_name,
        cmd: ["ruby", "decom_log_microservice.rb", microservice_name],
        work_dir: '/cosmos/lib/cosmos/microservices',
        topics: decom_topic_list,
        target_names: [@name],
        plugin: plugin,
        scope: @scope)
      microservice.create
      microservice.deploy(gem_path, variables)
      Logger.info "Configured microservice #{microservice_name}"
    end
  end
end
