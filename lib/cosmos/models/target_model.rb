require 'cosmos/models/model'
require 'zip'
require 'zip/filesystem'
require 'fileutils'
require 'tempfile'

module Cosmos
  class TargetModel < Model
    PRIMARY_KEY = 'cosmos_targets'

    attr_accessor :folder_name
    attr_accessor :requires
    attr_accessor :ignored_parameters
    attr_accessor :ignored_items
    attr_accessor :cmd_tlm_files
    attr_accessor :cmd_unique_id_mode
    attr_accessor :tlm_unique_id_mode
    attr_accessor :id

    def initialize(
      name:,
      folder_name: nil,
      requires: [],
      ignored_parameters: [],
      ignored_items: [],
      cmd_tlm_files: [],
      cmd_unique_id_mode: false,
      tlm_unique_id_mode: false,
      id: nil,
      updated_at: nil,
      scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name, updated_at: updated_at)
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
        'updated_at' => @updated_at
      }
    end

    def as_config
      "TARGET #{@folder_name} #{@name}\n"
    end

    def self.handle_config(parser, keyword, parameters, scope:)
      case keyword
      when 'TARGET'
        usage = "#{keyword} <TARGET FOLDER NAME> <TARGET NAME>"
        parser.verify_num_parameters(2, 2, usage)
        #STDOUT.puts parameters.inspect
        return self.new(name: parameters[1].to_s.upcase, folder_name: parameters[0].to_s.upcase, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Target: #{keyword} #{parameters.join(" ")}")
      end
    end

    def handle_config(parser, keyword, parameters, scope:)
      raise "Unsupported keyword for TARGET: #{keyword}"
    end

    def self.get(name:, scope: nil)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope: nil)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def self.all(scope: nil)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def deploy(gem_path, variables, scope:)
      rubys3_client = Aws::S3::Client.new
      variables["target_name"] = @name
      start_path = "/targets/#{@folder_name}/"
      temp_dir = Dir.mktmpdir
      begin
        #STDOUT.puts gem_path + start_path + "**/*"
        Dir.glob(gem_path + start_path + "**/*") do |filename|
          next if filename == '.' or filename == '..' or File.directory?(filename)
          path = filename.split(gem_path)[-1]
          target_folder_path = path.split(start_path)[-1]
          key = "#{scope}/targets/#{@name}/" + target_folder_path

          # Load target files
          data = File.read(filename, mode: "rb")
          data = ERB.new(data).result(create_erb_binding(variables)) if data.is_printable?
          local_path = File.join(temp_dir, @name, target_folder_path)
          FileUtils.mkdir_p(File.dirname(local_path))
          File.open(local_path, 'wb') {|file| file.write(data)}
          rubys3_client.put_object(bucket: 'config', key: key, body: data)
        end

        # Build target id
        target_files = []
        target_folder = File.join(temp_dir, @name)
        Find.find(target_folder) { |file| target_files << file }
        target_files.sort!
        hash = Cosmos.hash_files(target_files, nil, 'SHA256').hexdigest
        File.open(File.join(target_folder, 'target_id.txt'), 'wb') {|file| file.write(hash)}
        key = "#{scope}/targets/#{@name}/target_id.txt"
        rubys3_client.put_object(bucket: 'config', key: key, body: hash)

        # Build target archive
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
          s3_key = key = "#{scope}/target_archives/#{@name}/#{@name}_current.zip"
          rubys3_client.put_object(bucket: 'config', key: s3_key, body: file)
        end
        File.open(output_file, 'rb') do |file|
          s3_key = key = "#{scope}/target_archives/#{@name}/#{@name}_#{hash}.zip"
          rubys3_client.put_object(bucket: 'config', key: s3_key, body: file)
        end

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

        # Load Packet Definitions
        system.telemetry.all.each do |target_name, packets|
          Store.instance.del("#{scope}__cosmostlm__#{target_name}")
          packets.each do |packet_name, packet|
            Logger.info "Configuring tlm packet: #{target_name} #{packet_name}"
            Store.instance.hset("#{scope}__cosmostlm__#{target_name}", packet_name, JSON.generate(packet.as_json))
          end
        end
        system.commands.all.each do |target_name, packets|
          Store.instance.del("#{scope}__cosmoscmd__#{target_name}")
          packets.each do |packet_name, packet|
            Logger.info "Configuring cmd packet: #{target_name} #{packet_name}"
            Store.instance.hset("#{scope}__cosmoscmd__#{target_name}", packet_name, JSON.generate(packet.as_json))
          end
        end

        # Setup microservices for this target
        command_topic_list = []
        packet_topic_list = []
        begin
          system.commands.packets(@name).each do |packet_name, packet|
            command_topic_list << "#{scope}__COMMAND__#{@name}__#{packet_name}"
          end
        rescue
          # No command packets for this target
        end
        begin
          system.telemetry.packets(@name).each do |packet_name, packet|
            packet_topic_list << "#{scope}__TELEMETRY__#{@name}__#{packet_name}"
          end
        rescue
          # No telemetry packets for this target
        end
        Store.instance.initialize_streams(command_topic_list)
        Store.instance.initialize_streams(packet_topic_list)
        return unless packet_topic_list.length > 0

        # Decom Microservice
        microservice_name = "#{scope}__DECOM__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          cmd: ["ruby", "decom_microservice.rb", microservice_name],
          work_dir: '/cosmos/lib/cosmos/microservices',
          topics: packet_topic_list,
          target_names: [@name],
          scope: scope)
        microservice.create
        microservice.deploy(gem_path, variables, scope: scope)
        Logger.info "Configured microservice #{microservice_name}"

        # Cvt Microservice
        decom_topic_list = []
        begin
          system.telemetry.packets(@name).each do |packet_name, packet|
            decom_topic_list << "#{scope}__DECOM__#{@name}__#{packet_name}"
          end
        rescue
          # No telemetry packets for this target
        end
        Store.instance.initialize_streams(decom_topic_list)
        microservice_name = "#{scope}__CVT__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          cmd: ["ruby", "cvt_microservice.rb", microservice_name],
          work_dir: '/cosmos/lib/cosmos/microservices',
          topics: decom_topic_list,
          scope: scope)
        microservice.create
        microservice.deploy(gem_path, variables, scope: scope)
        Logger.info "Configured microservice #{microservice_name}"

        # PacketLog Microservice
        microservice_name = "#{scope}__PACKETLOG__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          cmd: ["ruby", "packet_log_microservice.rb", microservice_name],
          work_dir: '/cosmos/lib/cosmos/microservices',
          topics: packet_topic_list,
          target_names: [@name],
          scope: scope)
        microservice.create
        microservice.deploy(gem_path, variables, scope: scope)
        Logger.info "Configured microservice #{microservice_name}"

        # DecomLog Microservice
        microservice_name = "#{scope}__DECOMLOG__#{@name}"
        microservice = MicroserviceModel.new(
          name: microservice_name,
          cmd: ["ruby", "decom_log_microservice.rb", microservice_name],
          work_dir: '/cosmos/lib/cosmos/microservices',
          topics: decom_topic_list,
          target_names: [@name],
          scope: scope)
        microservice.create
        microservice.deploy(gem_path, variables, scope: scope)
        Logger.info "Configured microservice #{microservice_name}"
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
      end
    end
  end
end
