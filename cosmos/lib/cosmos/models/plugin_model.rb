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

require 'rubygems'
require 'rubygems/package'
require 'cosmos'
require 'cosmos/utilities/s3'
require 'cosmos/utilities/store'
require 'cosmos/config/config_parser'
require 'cosmos/models/model'
require 'cosmos/models/gem_model'
require 'cosmos/models/target_model'
require 'cosmos/models/interface_model'
require 'cosmos/models/router_model'
require 'cosmos/models/tool_model'
require 'cosmos/models/widget_model'
require 'cosmos/models/microservice_model'
require 'tmpdir'
require 'tempfile'

module Cosmos
  # Represents a COSMOS plugin that can consist of targets, interfaces, routers
  # microservices and tools. The PluginModel installs all these pieces as well
  # as destroys them all when the plugin is removed.
  class PluginModel < Model
    PRIMARY_KEY = 'cosmos_plugins'

    attr_accessor :variables
    attr_accessor :plugin_txt_lines

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

    # Called by the PluginsController to parse the plugin variables
    # Doesn't actaully create the plugin during the phase
<<<<<<< HEAD
    def self.install_phase1(gem_file_path, existing_variables: nil, existing_plugin_txt_lines: nil, process_existing: false, scope:, validate_only: false)
      gem_name = File.basename(gem_file_path).split("__")[0]

      temp_dir = Dir.mktmpdir
      tf = nil
      begin
        if File.exists?(gem_file_path)
          # Load gem to internal gem server
          Cosmos::GemModel.put(gem_file_path, gem_install: false, scope: scope) unless validate_only
        else
          gem_file_path = Cosmos::GemModel.get(temp_dir, gem_name)
        end

        # Extract gem and process plugin.txt to determine what VARIABLEs need to be filled in
        pkg = Gem::Package.new(gem_file_path)

        if existing_plugin_txt_lines and process_existing
          # This is only used in cosmos load when everything is known
          plugin_txt_lines = existing_plugin_txt_lines
          file_data = existing_plugin_txt_lines.join("\n")
          tf = Tempfile.new("plugin.txt")
          tf.write(file_data)
          tf.close
          plugin_txt_path = tf.path
        else
          # Otherwise we always process the new and return both
          pkg.extract_files(temp_dir)
          plugin_txt_path = File.join(temp_dir, 'plugin.txt')
          plugin_text = File.read(plugin_txt_path)
          plugin_txt_lines = []
          plugin_text.each_line do |line|
            plugin_txt_lines << line.chomp
          end
        end

        parser = Cosmos::ConfigParser.new("http://cosmosc2.com")

        # Phase 1 Gather Variables
        variables = {}
        parser.parse_file(plugin_txt_path,
                          false,
                          true,
                          false) do |keyword, params|
          case keyword
          when 'VARIABLE'
            usage = "#{keyword} <Variable Name> <Default Value>"
            parser.verify_num_parameters(2, nil, usage)
            variable_name = params[0]
            value = params[1..-1].join(" ")
            variables[variable_name] = value
            if existing_variables && existing_variables.key?(variable_name)
              variables[variable_name] = existing_variables[variable_name]
            end
            # Ignore everything else during phase 1
          end
        end

        model = PluginModel.new(name: gem_name, variables: variables, plugin_txt_lines: plugin_txt_lines, scope: scope)
        result = model.as_json
        result['existing_plugin_txt_lines'] = existing_plugin_txt_lines if existing_plugin_txt_lines and not process_existing and existing_plugin_txt_lines != result['plugin_txt_lines']
        return result
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
        tf.unlink if tf
      end
    end

    # Called by the PluginsController to create the plugin
    # Because this uses ERB it must be run in a seperate process from the API to
    # prevent corruption and single require problems in the current proces
<<<<<<< HEAD
    def self.install_phase2(plugin_hash, scope:, validate_only: false)
      rubys3_client = Aws::S3::Client.new

      # Ensure config bucket exists
      unless validate_only
        begin
          rubys3_client.head_bucket(bucket: 'config')
        rescue Aws::S3::Errors::NotFound
          rubys3_client.create_bucket(bucket: 'config')
        end
      end

      # Register plugin to aid in uninstall if install fails
      plugin_hash.delete("existing_plugin_txt_lines")
      plugin_model = PluginModel.new(**(plugin_hash.transform_keys(&:to_sym)), scope: scope)
      plugin_model.create unless validate_only

      temp_dir = Dir.mktmpdir
      begin
        tf = nil

        # Get the gem from local gem server
        gem_name = plugin_hash['name'].split("__")[0]
        gem_file_path = Cosmos::GemModel.get(temp_dir, gem_name)

        # Actually install the gem now (slow)
        Cosmos::GemModel.install(gem_file_path, scope: scope)

        # Extract gem contents
        gem_path = File.join(temp_dir, "gem")
        FileUtils.mkdir_p(gem_path)
        pkg = Gem::Package.new(gem_file_path)
        needs_dependencies = pkg.spec.runtime_dependencies.length > 0
        pkg.extract_files(gem_path)

        # Temporarily add all lib folders from the gem to the end of the load path
        load_dirs = []
        begin
          Dir.glob("#{gem_path}/**/*").each do |load_dir|
            if File.directory?(load_dir) and File.basename(load_dir) == 'lib'
              load_dirs << load_dir
              $LOAD_PATH << load_dir
            end
          end

          # Process plugin.txt file
          file_data = plugin_hash['plugin_txt_lines'].join("\n")
          tf = Tempfile.new("plugin.txt")
          tf.write(file_data)
          tf.close
          plugin_txt_path = tf.path
          variables = plugin_hash['variables']
          if File.exist?(plugin_txt_path)
            parser = Cosmos::ConfigParser.new("http://cosmosc2.com")

            current_model = nil
            parser.parse_file(plugin_txt_path, false, true, true, variables) do |keyword, params|
              case keyword
              when 'VARIABLE'
                # Ignore during phase 2
              when 'TARGET', 'INTERFACE', 'ROUTER', 'MICROSERVICE', 'TOOL', 'WIDGET'
                if current_model
                  current_model.create unless validate_only
                  current_model.deploy(gem_path, variables, validate_only: validate_only)
                  current_model = nil
                end
                current_model = Cosmos.const_get((keyword.capitalize + 'Model').intern).handle_config(parser, keyword, params, plugin: plugin_model.name, needs_dependencies: needs_dependencies, scope: scope)
              else
                if current_model
                  current_model.handle_config(parser, keyword, params)
                else
                  raise "Invalid keyword #{keyword} in plugin.txt"
                end
              end
            end
            if current_model
              current_model.create unless validate_only
              current_model.deploy(gem_path, variables, validate_only: validate_only)
              current_model = nil
            end
          end
        ensure
          load_dirs.each do |load_dir|
            $LOAD_PATH.delete(load_dir)
          end
        end
      rescue => err
        # Install failed - need to cleanup
        plugin_model.destroy unless validate_only
        raise err
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exist?(temp_dir)
        tf.unlink if tf
      end
    end

    def initialize(
      name:,
      variables: {},
      plugin_txt_lines: [],
      updated_at: nil,
      scope:
    )
      super("#{scope}__#{PRIMARY_KEY}", name: name, updated_at: updated_at, scope: scope)
      @variables = variables
      @plugin_txt_lines = plugin_txt_lines
    end

    def create(update: false, force: false)
      @name = @name + "__#{Time.now.utc.strftime("%Y%m%d%H%M%S")}" unless update
      super(update: update, force: force)
    end

    def as_json
      {
        'name' => @name,
        'variables' => @variables,
        'plugin_txt_lines' => @plugin_txt_lines,
        'updated_at' => @updated_at
      }
    end

    # Undeploy all models associated with this plugin
    def undeploy
      [ToolModel, TargetModel, InterfaceModel, RouterModel, MicroserviceModel, WidgetModel].each do |model|
        model.find_all_by_plugin(plugin: @name, scope: @scope).each do |name, model_instance|
          model_instance.destroy
        end
      end
    end

    # Reinstall
    def restore
      plugin_hash = self.as_json
      plugin_hash['name'] = plugin_hash['name'].split("__")[0]
      Cosmos::PluginModel.install_phase2(plugin_hash, scope: @scope)
      @destroyed = false
    end
  end
end
