require 'rubygems'
require 'rubygems/package'
require 'cosmos/utilities/s3'
require 'cosmos/utilities/store'
require 'cosmos/config/config_parser'
require 'cosmos/models/model'
require 'cosmos/models/target_model'
require 'cosmos/models/interface_model'
require 'cosmos/models/router_model'
require 'cosmos/models/tool_model'
require 'cosmos/models/microservice_model'

module Cosmos
  class PluginModel < Model
    PRIMARY_KEY = 'cosmos_plugins'

    def initialize(
      name:,
      variables: {},
      updated_at: nil,
      scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name, updated_at: updated_at)
      @variables = variables
    end

    def create(update: false, force: false)
      @name = @name + "__#{Time.now.utc.strftime("%Y%m%d%H%M%S")}" unless update
      super(update: update, force: force)
    end

    def as_json
      {
        'name' => @name,
        'variables' => @variables,
        'updated_at' => @updated_at
      }
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

    def self.install_phase1(gem_file_path, scope:)
      gem_filename = File.basename(gem_file_path)

      # Load gem to internal gem server
      result = Cosmos::GemModel.put(gem_file_path)

      # Extract gem and process plugin.txt to determine what VARIABLEs need to be filled in
      pkg = Gem::Package.new(gem_file_path)

      temp_dir = Dir.mktmpdir
      begin
        pkg.extract_files(temp_dir)
        plugin_txt_path = File.join(temp_dir, 'plugin.txt')
        if File.exist?(plugin_txt_path)
          parser = Cosmos::ConfigParser.new("http://cosmosrb.com")

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
              # Ignore everything else during phase 1
            end
          end

          model = PluginModel.new(name: gem_filename, variables: variables, scope: scope)
          return model.as_json
        end
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
      end
    end

    def self.install_phase2(name, variables, scope:)
      rubys3_client = Aws::S3::Client.new

      # Ensure config bucket exists
      begin
        rubys3_client.head_bucket(bucket: 'config')
      rescue Aws::S3::Errors::NotFound
        rubys3_client.create_bucket(bucket: 'config')
      end

      # Register plugin to aid in uninstall if install fails
      model = PluginModel.new(name: name, variables: variables, scope: scope)
      model.create

      temp_dir = Dir.mktmpdir
      begin
        # Get the gem from local gem server
        gem_file_path = Cosmos::GemModel.get(name, temp_dir)
        gem_path = File.join(temp_dir, "gem")
        FileUtils.mkdir_p(gem_path)
        pkg = Gem::Package.new(gem_file_path)
        pkg.extract_files(gem_path)

        # Process plugin.txt file
        plugin_txt_path = File.join(gem_path, 'plugin.txt')
        if File.exist?(plugin_txt_path)
          parser = Cosmos::ConfigParser.new("http://cosmosrb.com")

          current_model = nil
          parser.parse_file(plugin_txt_path, false, true, true, variables) do |keyword, params|
            case keyword
            when 'VARIABLE'
              # Ignore during phase 2
            when 'TARGET', 'INTERFACE', 'ROUTER', 'MICROSERVICE', 'TOOL'
              if current_model
                current_model.create
                current_model.deploy(gem_path, variables, scope: scope)
                current_model = nil
              end
              current_model = Cosmos.const_get((keyword.capitalize + 'Model').intern).handle_config(parser, keyword, params, scope: scope)
            else
              if current_model
                current_model.handle_config(parser, keyword, params, scope: scope)
              else
                raise "Invalid keyword #{keyword} in plugin.txt"
              end
            end
          end
          if current_model
            current_model.create
            current_model.deploy(gem_path, variables, scope: scope)
            current_model = nil
          end
        end
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
      end
    end # def self.install

  end # class Plugin
end # module Cosmos