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

require 'openc3/top_level'
require 'openc3/models/model'
require 'openc3/models/cvt_model'
require 'openc3/models/microservice_model'
require 'openc3/topics/limits_event_topic'
require 'openc3/topics/config_topic'
require 'openc3/system'
require 'openc3/utilities/s3'
require 'openc3/utilities/zip'
require 'fileutils'
require 'tmpdir'

module OpenC3
  # Manages the target in Redis. It stores the target itself under the
  # <SCOPE>__openc3_targets key under the target name field. All the command packets
  # in the target are stored under the <SCOPE>__openc3cmd__<TARGET NAME> key and the
  # telemetry under the <SCOPE>__openc3tlm__<TARGET NAME> key. Any new limits sets
  # are merged into the <SCOPE>__limits_sets key as fields. Any new limits groups are
  # created under <SCOPE>__limits_groups with field name. These Redis key/fields are
  # all removed when the undeploy method is called.
  class TargetModel < Model
    PRIMARY_KEY = 'openc3_targets'
    VALID_TYPES = %i(CMD TLM)

    attr_accessor :folder_name
    attr_accessor :requires
    attr_accessor :ignored_parameters
    attr_accessor :ignored_items
    attr_accessor :limits_groups
    attr_accessor :cmd_tlm_files
    attr_accessor :cmd_unique_id_mode
    attr_accessor :tlm_unique_id_mode
    attr_accessor :id
    attr_accessor :cmd_log_cycle_time
    attr_accessor :cmd_log_cycle_size
    attr_accessor :cmd_log_retain_time
    attr_accessor :cmd_decom_log_cycle_time
    attr_accessor :cmd_decom_log_cycle_size
    attr_accessor :cmd_decom_log_retain_time
    attr_accessor :tlm_log_cycle_time
    attr_accessor :tlm_log_cycle_size
    attr_accessor :tlm_log_retain_time
    attr_accessor :tlm_decom_log_cycle_time
    attr_accessor :tlm_decom_log_cycle_size
    attr_accessor :tlm_decom_log_retain_time
    attr_accessor :reduced_minute_log_retain_time
    attr_accessor :reduced_hour_log_retain_time
    attr_accessor :reduced_day_log_retain_time
    attr_accessor :cleanup_poll_time
    attr_accessor :needs_dependencies

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope:)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def self.all(scope:)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    # @return [Array] Array of all the packet names
    def self.packet_names(target_name, type: :TLM, scope:)
      raise "Unknown type #{type} for #{target_name}" unless VALID_TYPES.include?(type)
      # If the key doesn't exist or if there are no packets we return empty array
      Store.hkeys("#{scope}__openc3#{type.to_s.downcase}__#{target_name}").sort
    end
  
    # @return [Hash] Packet hash or raises an exception
    def self.packet(target_name, packet_name, type: :TLM, scope:)
      raise "Unknown type #{type} for #{target_name} #{packet_name}" unless VALID_TYPES.include?(type)

      # Assume it exists and just try to get it to avoid an extra call to Store.exist?
      json = Store.hget("#{scope}__openc3#{type.to_s.downcase}__#{target_name}", packet_name)
      raise "Packet '#{target_name} #{packet_name}' does not exist" if json.nil?

      JSON.parse(json, :allow_nan => true, :create_additions => true)
    end

    # @return [Array>Hash>] All packet hashes under the target_name
    def self.packets(target_name, type: :TLM, scope:)
      raise "Unknown type #{type} for #{target_name}" unless VALID_TYPES.include?(type)
      raise "Target '#{target_name}' does not exist" unless get(name: target_name, scope: scope)

      result = []
      packets = Store.hgetall("#{scope}__openc3#{type.to_s.downcase}__#{target_name}")
      packets.sort.each do |packet_name, packet_json|
        result << JSON.parse(packet_json, :allow_nan => true, :create_additions => true)
      end
      result
    end

    # @return [Array>Hash>] All packet hashes under the target_name
    def self.all_packet_name_descriptions(target_name, type: :TLM, scope:)
      self.packets(target_name, type: type, scope: scope).map! { |hash| hash.slice("packet_name", "description") }
    end

    def self.set_packet(target_name, packet_name, packet, type: :TLM, scope:)
      raise "Unknown type #{type} for #{target_name} #{packet_name}" unless VALID_TYPES.include?(type)

      begin
        Store.hset("#{scope}__openc3tlm__#{target_name}", packet_name, JSON.generate(packet.as_json(:allow_nan => true)))
      rescue JSON::GeneratorError => err
        Logger.error("Invalid text present in #{target_name} #{packet_name} #{type.to_s.downcase} packet")
        raise err
      end
    end

    # @return [Hash] Item hash or raises an exception
    def self.packet_item(target_name, packet_name, item_name, type: :TLM, scope:)
      packet = packet(target_name, packet_name, type: type, scope: scope)
      item = packet['items'].find { |item| item['name'] == item_name.to_s }
      raise "Item '#{packet['target_name']} #{packet['packet_name']} #{item_name}' does not exist" unless item
      item
    end

    # @return [Array<Hash>] Item hash array or raises an exception
    def self.packet_items(target_name, packet_name, items, type: :TLM, scope:)
      packet = packet(target_name, packet_name, type: type, scope: scope)
      found = packet['items'].find_all { |item| items.map(&:to_s).include?(item['name']) }
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

    # @return [Hash{String => Array<Array<String, String, String>>}]
    def self.limits_groups(scope:)
      groups = Store.hgetall("#{scope}__limits_groups")
      if groups
        groups.map { |group, items| [group, JSON.parse(items, :allow_nan => true, :create_additions => true)] }.to_h
      else
        {}
      end
    end

    # Called by the PluginModel to allow this class to validate it's top-level keyword: "TARGET"
    def self.handle_config(parser, keyword, parameters, plugin: nil, needs_dependencies: false, scope:)
      case keyword
      when 'TARGET'
        usage = "#{keyword} <TARGET FOLDER NAME> <TARGET NAME>"
        parser.verify_num_parameters(2, 2, usage)
        parser.verify_parameter_naming(2) # Target name is the 2nd parameter
        return self.new(name: parameters[1].to_s.upcase, folder_name: parameters[0].to_s.upcase, plugin: plugin,  needs_dependencies: needs_dependencies, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Target: #{keyword} #{parameters.join(" ")}")
      end
    end

    def initialize(
      name:,
      folder_name: nil,
      requires: [],
      ignored_parameters: [],
      ignored_items: [],
      limits_groups: [],
      cmd_tlm_files: [],
      cmd_unique_id_mode: false,
      tlm_unique_id_mode: false,
      id: nil,
      updated_at: nil,
      plugin: nil,
      cmd_log_cycle_time: 600,
      cmd_log_cycle_size: 50_000_000,
      cmd_log_retain_time: nil,
      cmd_decom_log_cycle_time: 600,
      cmd_decom_log_cycle_size: 50_000_000,
      cmd_decom_log_retain_time: nil,
      tlm_log_cycle_time: 600,
      tlm_log_cycle_size: 50_000_000,
      tlm_log_retain_time: nil,
      tlm_decom_log_cycle_time: 600,
      tlm_decom_log_cycle_size: 50_000_000,
      tlm_decom_log_retain_time: nil,
      reduced_minute_log_retain_time: nil,
      reduced_hour_log_retain_time: nil,
      reduced_day_log_retain_time: nil,
      cleanup_poll_time: 900,
      needs_dependencies: false,
      scope:
    )
      super("#{scope}__#{PRIMARY_KEY}", name: name, plugin: plugin, updated_at: updated_at,
        cmd_log_cycle_time: cmd_log_cycle_time, cmd_log_cycle_size: cmd_log_cycle_size,
        cmd_log_retain_time: cmd_log_retain_time,
        cmd_decom_log_cycle_time: cmd_decom_log_cycle_time, cmd_decom_log_cycle_size: cmd_decom_log_cycle_size,
        cmd_decom_log_retain_time: cmd_decom_log_retain_time,
        tlm_log_cycle_time: tlm_log_cycle_time, tlm_log_cycle_size: tlm_log_cycle_size,
        tlm_log_retain_time: tlm_log_retain_time,
        tlm_decom_log_cycle_time: tlm_decom_log_cycle_time, tlm_decom_log_cycle_size: tlm_decom_log_cycle_size,
        tlm_decom_log_retain_time: tlm_decom_log_retain_time,
        reduced_minute_log_retain_time: reduced_minute_log_retain_time,
        reduced_hour_log_retain_time: reduced_hour_log_retain_time, reduced_day_log_retain_time: reduced_day_log_retain_time,
        cleanup_poll_time: cleanup_poll_time, needs_dependencies: needs_dependencies,
        scope: scope)
      @folder_name = folder_name
      @requires = requires
      @ignored_parameters = ignored_parameters
      @ignored_items = ignored_items
      @limits_groups = limits_groups
      @cmd_tlm_files = cmd_tlm_files
      @cmd_unique_id_mode = cmd_unique_id_mode
      @tlm_unique_id_mode = tlm_unique_id_mode
      @id = id
      @cmd_log_cycle_time = cmd_log_cycle_time
      @cmd_log_cycle_size = cmd_log_cycle_size
      @cmd_log_retain_time = cmd_log_retain_time
      @cmd_decom_log_cycle_time = cmd_decom_log_cycle_time
      @cmd_decom_log_cycle_size = cmd_decom_log_cycle_size
      @cmd_decom_log_retain_time = cmd_decom_log_retain_time
      @tlm_log_cycle_time = tlm_log_cycle_time
      @tlm_log_cycle_size = tlm_log_cycle_size
      @tlm_log_retain_time = tlm_log_retain_time
      @tlm_decom_log_cycle_time = tlm_decom_log_cycle_time
      @tlm_decom_log_cycle_size = tlm_decom_log_cycle_size
      @tlm_decom_log_retain_time = tlm_decom_log_retain_time
      @reduced_minute_log_retain_time = reduced_minute_log_retain_time
      @reduced_hour_log_retain_time = reduced_hour_log_retain_time
      @reduced_day_log_retain_time = reduced_day_log_retain_time
      @cleanup_poll_time = cleanup_poll_time
      @needs_dependencies = needs_dependencies
    end

    def as_json(*a)
      {
        'name' => @name,
        'folder_name' => @folder_name,
        'requires' => @requires,
        'ignored_parameters' => @ignored_parameters,
        'ignored_items' => @ignored_items,
        'limits_groups' => @limits_groups,
        'cmd_tlm_files' => @cmd_tlm_files,
        'cmd_unique_id_mode' => cmd_unique_id_mode,
        'tlm_unique_id_mode' => @tlm_unique_id_mode,
        'id' => @id,
        'updated_at' => @updated_at,
        'plugin' => @plugin,
        'cmd_log_cycle_time' => @cmd_log_cycle_time,
        'cmd_log_cycle_size' => @cmd_log_cycle_size,
        'cmd_log_retain_time' => @cmd_log_retain_time,
        'cmd_decom_log_cycle_time' => @cmd_decom_log_cycle_time,
        'cmd_decom_log_cycle_size' => @cmd_decom_log_cycle_size,
        'cmd_decom_log_retain_time' => @cmd_decom_log_retain_time,
        'tlm_log_cycle_time' => @tlm_log_cycle_time,
        'tlm_log_cycle_size' => @tlm_log_cycle_size,
        'tlm_log_retain_time' => @tlm_log_retain_time,
        'tlm_decom_log_cycle_time' => @tlm_decom_log_cycle_time,
        'tlm_decom_log_cycle_size' => @tlm_decom_log_cycle_size,
        'tlm_decom_log_retain_time' => @tlm_decom_log_retain_time,
        'reduced_minute_log_retain_time' => @reduced_minute_log_retain_time,
        'reduced_hour_log_retain_time' => @reduced_hour_log_retain_time,
        'reduced_day_log_retain_time' => @reduced_day_log_retain_time,
        'cleanup_poll_time' => @cleanup_poll_time,
        'needs_dependencies' => @needs_dependencies,
      }
    end

    def as_config
      "TARGET #{@folder_name} #{@name}\n"
    end

    # Handles Target specific configuration keywords
    def handle_config(parser, keyword, parameters)
      case keyword
      when 'CMD_LOG_CYCLE_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Maximum time between files in seconds>")
        @cmd_log_cycle_time = parameters[0].to_i
      when 'CMD_LOG_CYCLE_SIZE'
        parser.verify_num_parameters(1, 1, "#{keyword} <Maximum file size in bytes>")
        @cmd_log_cycle_size = parameters[0].to_i
      when 'CMD_LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for cmd log files in seconds - nil = Forever>")
        @cmd_log_retain_time = ConfigParser.handle_nil(parameters[0])
        @cmd_log_retain_time = @cmd_log_retain_time.to_i if @cmd_log_retain_time
      when 'CMD_DECOM_LOG_CYCLE_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Maximum time between files in seconds>")
        @cmd_decom_log_cycle_time = parameters[0].to_i
      when 'CMD_DECOM_LOG_CYCLE_SIZE'
        parser.verify_num_parameters(1, 1, "#{keyword} <Maximum file size in bytes>")
        @cmd_decom_log_cycle_size = parameters[0].to_i
      when 'CMD_DECOM_LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for cmd decom log files in seconds - nil = Forever>")
        @cmd_decom_log_retain_time = ConfigParser.handle_nil(parameters[0])
        @cmd_decom_log_retain_time = @cmd_decom_log_retain_time.to_i if @cmd_decom_log_retain_time
      when 'TLM_LOG_CYCLE_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Maximum time between files in seconds>")
        @tlm_log_cycle_time = parameters[0].to_i
      when 'TLM_LOG_CYCLE_SIZE'
        parser.verify_num_parameters(1, 1, "#{keyword} <Maximum file size in bytes>")
        @tlm_log_cycle_size = parameters[0].to_i
      when 'TLM_LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for tlm log files in seconds - nil = Forever>")
        @tlm_log_retain_time = ConfigParser.handle_nil(parameters[0])
        @tlm_log_retain_time = @tlm_log_retain_time.to_i if @tlm_log_retain_time
      when 'TLM_DECOM_LOG_CYCLE_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Maximum time between files in seconds>")
        @tlm_decom_log_cycle_time = parameters[0].to_i
      when 'TLM_DECOM_LOG_CYCLE_SIZE'
        parser.verify_num_parameters(1, 1, "#{keyword} <Maximum file size in bytes>")
        @tlm_decom_log_cycle_size = parameters[0].to_i
      when 'TLM_DECOM_LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for tlm decom log files in seconds - nil = Forever>")
        @tlm_decom_log_retain_time = ConfigParser.handle_nil(parameters[0])
        @tlm_decom_log_retain_time = @tlm_decom_log_retain_time.to_i if @tlm_decom_log_retain_time
      when 'REDUCED_MINUTE_LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for reduced minute log files in seconds - nil = Forever>")
        @reduced_minute_log_retain_time = ConfigParser.handle_nil(parameters[0])
        @reduced_minute_log_retain_time = @reduced_minute_log_retain_time.to_i if @reduced_minute_log_retain_time
      when 'REDUCED_HOUR_LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for reduced hour log files in seconds - nil = Forever>")
        @reduced_hour_log_retain_time = ConfigParser.handle_nil(parameters[0])
        @reduced_hour_log_retain_time = @reduced_hour_log_retain_time.to_i if @reduced_hour_log_retain_time
      when 'REDUCED_DAY_LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for reduced day log files in seconds - nil = Forever>")
        @reduced_day_log_retain_time = ConfigParser.handle_nil(parameters[0])
        @reduced_day_log_retain_time = @reduced_day_log_retain_time.to_i if @reduced_day_log_retain_time
      when 'LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for all log files in seconds - nil = Forever>")
        log_retain_time = ConfigParser.handle_nil(parameters[0])
        if log_retain_time
          @cmd_log_retain_time = log_retain_time.to_i
          @cmd_decom_log_retain_time = log_retain_time.to_i
          @tlm_log_retain_time = log_retain_time.to_i
          @tlm_decom_log_retain_time = log_retain_time.to_i
        end
      when 'REDUCED_LOG_RETAIN_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Retention time for all reduced log files in seconds - nil = Forever>")
        reduced_log_retain_time = ConfigParser.handle_nil(parameters[0])
        if reduced_log_retain_time
          @reduced_minute_log_retain_time = reduced_log_retain_time.to_i
          @reduced_hour_log_retain_time = reduced_log_retain_time.to_i
          @reduced_day_log_retain_time = reduced_log_retain_time.to_i
        end
      when 'CLEANUP_POLL_TIME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Cleanup polling period in seconds>")
        @cleanup_poll_time = parameters[0].to_i
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Target: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def deploy(gem_path, variables, validate_only: false)
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
          key = "#{@scope}/targets/#{@name}/#{target_folder_path}"

          # Load target files
          @filename = filename # For render
          data = File.read(filename, mode: "rb")
          begin
            OpenC3.set_working_dir(File.dirname(filename)) do
              data = ERB.new(data, trim_mode: "-").result(binding.set_variables(variables)) if data.is_printable? and File.basename(filename)[0] != '_'
            end
          rescue => error
            raise "ERB error parsing: #{filename}: #{error.formatted}"
          end
          local_path = File.join(temp_dir, @name, target_folder_path)
          FileUtils.mkdir_p(File.dirname(local_path))
          File.open(local_path, 'wb') { |file| file.write(data) }
          found = true
          rubys3_client.put_object(bucket: 'config', key: key, body: data) unless validate_only
        end
        raise "No target files found at #{target_path}" unless found

        target_folder = File.join(temp_dir, @name)
        # Build a System for just this target
        system = System.new([@name], temp_dir)
        if variables["xtce_output"]
          puts "Converting target #{@name} to .xtce files in #{variables["xtce_output"]}/#{@name}"
          system.packet_config.to_xtce(variables["xtce_output"])
        end
        unless validate_only
          build_target_archive(rubys3_client, temp_dir, target_folder)
          system = update_store(system)
          deploy_microservices(gem_path, variables, system)
          ConfigTopic.write({ kind: 'created', type: 'target', name: @name, plugin: @plugin }, scope: @scope)
        end
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

      self.class.get_model(name: @name, scope: @scope).limits_groups.each do |group|
        Store.hdel("#{@scope}__limits_groups", group)
      end
      self.class.packets(@name, type: :CMD, scope: @scope).each do |packet|
        Topic.del("#{@scope}__COMMAND__{#{@name}}__#{packet['packet_name']}")
        Topic.del("#{@scope}__DECOMCMD__{#{@name}}__#{packet['packet_name']}")
      end
      self.class.packets(@name, scope: @scope).each do |packet|
        Topic.del("#{@scope}__TELEMETRY__{#{@name}}__#{packet['packet_name']}")
        Topic.del("#{@scope}__DECOM__{#{@name}}__#{packet['packet_name']}")
        CvtModel.del(target_name: @name, packet_name: packet['packet_name'], scope: @scope)
        LimitsEventTopic.delete(@name, packet['packet_name'], scope: @scope)
      end
      Store.del("#{@scope}__openc3tlm__#{@name}")
      Store.del("#{@scope}__openc3cmd__#{@name}")

      # Note: these match the names of the services in deploy_microservices
      %w(DECOM COMMANDLOG DECOMCMDLOG PACKETLOG DECOMLOG REDUCER CLEANUP).each do |type|
        model = MicroserviceModel.get_model(name: "#{@scope}__#{type}__#{@name}", scope: @scope)
        model.destroy if model
      end
      ConfigTopic.write({ kind: 'deleted', type: 'target', name: @name, plugin: @plugin }, scope: @scope)
    end

    ##################################################
    # The following methods are implementation details
    ##################################################

    # Called by the ERB template to render a partial
    def render(template_name, options = {})
      raise "Partial name '#{template_name}' must begin with an underscore." if File.basename(template_name)[0] != '_'

      b = binding
      b.local_variable_set(:target_name, @name)
      if options[:locals]
        options[:locals].each { |key, value| b.local_variable_set(key, value) }
      end

      # Assume the file is there. If not we raise a pretty obvious error
      if File.expand_path(template_name) == template_name # absolute path
        path = template_name
      else # relative to the current @filename
        path = File.join(File.dirname(@filename), template_name)
      end

      begin
        OpenC3.set_working_dir(File.dirname(path)) do
          return ERB.new(File.read(path), trim_mode: "-").result(b)
        end
      rescue => error
        raise "ERB error parsing: #{path}: #{error.formatted}"
      end
    end

    def build_target_archive(rubys3_client, temp_dir, target_folder)
      target_files = []
      Find.find(target_folder) { |file| target_files << file }
      target_files.sort!
      hash = OpenC3.hash_files(target_files, nil, 'SHA256').hexdigest
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

    def update_store(system)
      target = system.targets[@name]

      # Add in the information from the target and update
      @requires = target.requires
      @ignored_parameters = target.ignored_parameters
      @ignored_items = target.ignored_items
      @cmd_tlm_files = target.cmd_tlm_files
      @cmd_unique_id_mode = target.cmd_unique_id_mode
      @tlm_unique_id_mode = target.tlm_unique_id_mode
      @id = target.id
      @limits_groups = system.limits.groups.keys
      update()

      # Store Packet Definitions
      system.telemetry.all.each do |target_name, packets|
        Store.del("#{@scope}__openc3tlm__#{target_name}")
        packets.each do |packet_name, packet|
          Logger.info "Configuring tlm packet: #{target_name} #{packet_name}"
          begin
            Store.hset("#{@scope}__openc3tlm__#{target_name}", packet_name, JSON.generate(packet.as_json(:allow_nan => true)))
          rescue JSON::GeneratorError => err
            Logger.error("Invalid text present in #{target_name} #{packet_name} tlm packet")
            raise err
          end
          json_hash = Hash.new
          packet.sorted_items.each do |item|
            json_hash[item.name] = nil
          end
          CvtModel.set(json_hash, target_name: packet.target_name, packet_name: packet.packet_name, scope: @scope)
        end
      end
      system.commands.all.each do |target_name, packets|
        Store.del("#{@scope}__openc3cmd__#{target_name}")
        packets.each do |packet_name, packet|
          Logger.info "Configuring cmd packet: #{target_name} #{packet_name}"
          begin
            Store.hset("#{@scope}__openc3cmd__#{target_name}", packet_name, JSON.generate(packet.as_json(:allow_nan => true)))
          rescue JSON::GeneratorError => err
            Logger.error("Invalid text present in #{target_name} #{packet_name} cmd packet")
            raise err
          end
        end
      end
      # Store Limits Groups
      system.limits.groups.each do |group, items|
        begin
          Store.hset("#{@scope}__limits_groups", group, JSON.generate(items))
        rescue JSON::GeneratorError => err
          Logger.error("Invalid text present in #{group} limits group")
          raise err
        end
      end
      # Merge in Limits Sets
      sets = Store.hgetall("#{@scope}__limits_sets")
      sets ||= {}
      system.limits.sets.each do |set|
        sets[set.to_s] = "false" unless sets.key?(set.to_s)
      end
      Store.hmset("#{@scope}__limits_sets", *sets)

      return system
    end

    def deploy_microservices(gem_path, variables, system)
      command_topic_list = []
      decom_command_topic_list = []
      packet_topic_list = []
      decom_topic_list = []
      begin
        system.commands.packets(@name).each do |packet_name, packet|
          command_topic_list << "#{@scope}__COMMAND__{#{@name}}__#{packet_name}"
          decom_command_topic_list << "#{@scope}__DECOMCMD__{#{@name}}__#{packet_name}"
        end
      rescue
        # No command packets for this target
      end
      begin
        system.telemetry.packets(@name).each do |packet_name, packet|
          packet_topic_list << "#{@scope}__TELEMETRY__{#{@name}}__#{packet_name}"
          decom_topic_list  << "#{@scope}__DECOM__{#{@name}}__#{packet_name}"
        end
      rescue
        # No telemetry packets for this target
      end
      # It's ok to call initialize_streams with an empty array
      Topic.initialize_streams(command_topic_list)
      Topic.initialize_streams(decom_command_topic_list)
      Topic.initialize_streams(packet_topic_list)
      Topic.initialize_streams(decom_topic_list)

      unless command_topic_list.empty?
        # CommandLog Microservice
        microservice_name = "#{@scope}__COMMANDLOG__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          folder_name: @folder_name,
          cmd: ["ruby", "log_microservice.rb", microservice_name],
          work_dir: '/openc3/lib/openc3/microservices',
          options: [
            ["RAW_OR_DECOM", "RAW"],
            ["CMD_OR_TLM", "CMD"],
            ["CYCLE_TIME", @cmd_log_cycle_time],
            ["CYCLE_SIZE", @cmd_log_cycle_size]
          ],
          topics: command_topic_list,
          target_names: [@name],
          plugin: @plugin,
          needs_dependencies: @needs_dependencies,
          scope: @scope
        )
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured microservice #{microservice_name}"

        # DecomCmdLog Microservice
        microservice_name = "#{@scope}__DECOMCMDLOG__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          folder_name: @folder_name,
          cmd: ["ruby", "log_microservice.rb", microservice_name],
          work_dir: '/openc3/lib/openc3/microservices',
          options: [
            ["RAW_OR_DECOM", "DECOM"],
            ["CMD_OR_TLM", "CMD"],
            ["CYCLE_TIME", @cmd_decom_log_cycle_time],
            ["CYCLE_SIZE", @cmd_decom_log_cycle_size]
          ],
          topics: decom_command_topic_list,
          target_names: [@name],
          plugin: @plugin,
          needs_dependencies: @needs_dependencies,
          scope: @scope
        )
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured microservice #{microservice_name}"
      end

      unless packet_topic_list.empty?
        # PacketLog Microservice
        microservice_name = "#{@scope}__PACKETLOG__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          folder_name: @folder_name,
          cmd: ["ruby", "log_microservice.rb", microservice_name],
          work_dir: '/openc3/lib/openc3/microservices',
          options: [
            ["RAW_OR_DECOM", "RAW"],
            ["CMD_OR_TLM", "TLM"],
            ["CYCLE_TIME", @tlm_log_cycle_time],
            ["CYCLE_SIZE", @tlm_log_cycle_size]
          ],
          topics: packet_topic_list,
          target_names: [@name],
          plugin: @plugin,
          needs_dependencies: @needs_dependencies,
          scope: @scope
        )
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured microservice #{microservice_name}"

        # DecomLog Microservice
        microservice_name = "#{@scope}__DECOMLOG__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          folder_name: @folder_name,
          cmd: ["ruby", "log_microservice.rb", microservice_name],
          work_dir: '/openc3/lib/openc3/microservices',
          options: [
            ["RAW_OR_DECOM", "DECOM"],
            ["CMD_OR_TLM", "TLM"],
            ["CYCLE_TIME", @tlm_decom_log_cycle_time],
            ["CYCLE_SIZE", @tlm_decom_log_cycle_size]
          ],
          topics: decom_topic_list,
          target_names: [@name],
          plugin: @plugin,
          needs_dependencies: @needs_dependencies,
          scope: @scope
        )
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured microservice #{microservice_name}"

        # Decommutation Microservice
        microservice_name = "#{@scope}__DECOM__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          folder_name: @folder_name,
          cmd: ["ruby", "decom_microservice.rb", microservice_name],
          work_dir: '/openc3/lib/openc3/microservices',
          topics: packet_topic_list,
          target_names: [@name],
          plugin: @plugin,
          needs_dependencies: @needs_dependencies,
          scope: @scope
        )
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured microservice #{microservice_name}"

        # Reducer Microservice
        microservice_name = "#{@scope}__REDUCER__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          folder_name: @folder_name,
          cmd: ["ruby", "reducer_microservice.rb", microservice_name],
          work_dir: '/openc3/lib/openc3/microservices',
          topics: decom_topic_list,
          plugin: @plugin,
          needs_dependencies: @needs_dependencies,
          scope: @scope
        )
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured microservice #{microservice_name}"
      end

      if @cmd_log_retain_time or @cmd_decom_log_retain_time or @tlm_log_retain_time or @tlm_decom_log_retain_time or
         @reduced_minute_log_retain_time or @reduced_hour_log_retain_time or @reduced_day_log_retain_time
        # Cleanup Microservice
        microservice_name = "#{@scope}__CLEANUP__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          cmd: ["ruby", "cleanup_microservice.rb", microservice_name],
          work_dir: '/openc3/lib/openc3/microservices',
          plugin: @plugin,
          scope: @scope
        )
        microservice.create
        microservice.deploy(gem_path, variables)
        Logger.info "Configured microservice #{microservice_name}"
      end
    end
  end
end
