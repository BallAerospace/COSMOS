require 'rubygems'
require 'rubygems/package'
require 'fileutils'
require 'cosmos/utilities/s3'
require 'cosmos/utilities/store'
require 'cosmos/config/config_parser'

module Cosmos
  class Plugin
    def self.install(gem_file_path)
      gem_filename = File.basename(gem_file_path)

      rubys3_client = Aws::S3::Client.new

      # Ensure targets bucket exists
      begin
        rubys3_client.head_bucket(bucket: 'targets')
      rescue Aws::S3::Errors::NotFound
        rubys3_client.create_bucket(bucket: 'targets')
      end

      # Ensure tools bucket exists
      begin
        rubys3_client.head_bucket(bucket: 'tools')
      rescue Aws::S3::Errors::NotFound
        rubys3_client.create_bucket(bucket: 'tools')
      end

      # Load gem to geminabox
      gems_host = ENV['COSMOS_GEMS_URL'] || ENV['COSMOS_DEVEL'] ? 'http://127.0.0.1:9292' : 'http://cosmos_gems:9292'
      #TODO

      # Handle cosmos plugin
      if gem_filename[0..6] == "cosmos-"
        STDOUT.puts "Cosmos plugin gem detected"

        # Initial register of the plugin without all info yet
        Cosmos::Store.instance.hset("DEFAULT__cosmos_plugins", gem_filename, "[]")

        pkg = Gem::Package.new(gem_file_path)

        temp_dir = Dir.mktmpdir
        begin
          pkg.extract_files(temp_dir)
          plugin_config = nil
          Dir.glob(temp_dir + "/**/*") do |filename|
            next if filename == '.' or filename == '..' or File.directory?(filename)
            path = filename.split(temp_dir)[-1]

            # Load target files
            if path[0..8] == '/targets/'
              STDOUT.puts "Uploading target file: #{path}"
              rubys3_client.put_object(bucket: 'targets', key: path[9..-1], body: File.read(filename, mode: "rb"))
            end

            # Load tool files
            if path[0..6] == '/tools/'
              STDOUT.puts "Uploading tool file: #{path}"
              rubys3_client.put_object(bucket: 'tools', key: path[7..-1], body: File.read(filename, mode: "rb"))
            end

            if path == "/plugin.txt"
              STDOUT.puts "Found plugin.txt"
              plugin_config = filename
            end
          end

          # Process plugin.txt file
          if plugin_config
            parser = Cosmos::ConfigParser.new("http://cosmosrb.com")

            # Phase 1 Gather Variables
            parser.parse_file(plugin_config) do |keyword, params|
              case keyword
                when 'COMMAND'
                  usage = "#{keyword} <TARGET NAME> <PACKET NAME>"
                  parser.verify_num_parameters(2, 2, usage)
                else
                  STDOUT.puts "Unknown keyword: #{keyword}"
              end
            end
          end
        ensure
          FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
        end

        # Register plugin with complete info
        Cosmos::Store.instance.hset("DEFAULT__cosmos_plugins", gem_filename, "[]")
      end
    end # def self.install

    def self.add_target(original_name, substitute_name, target_txt_filename)

    end

    def self.remove_target(target_name)

    end

  end # class Plugin
end # module Cosmos

class PluginsController < ApplicationController
  # List the installed plugins
  def index
    # TODO handle scopes
    render :json => Cosmos::Store.instance.hkeys("DEFAULT__cosmos_plugins")
  end

  # Add a new plugin
  def create
    file = params[:plugin]
    if file
      temp_dir = Dir.mktmpdir
      begin
        gem_file_path = temp_dir + '/' + file.original_filename
        FileUtils.cp(file.tempfile.path, gem_file_path)
        Cosmos::Plugin.install(gem_file_path)
      ensure
        FileUtils.remove_entry(temp_dir) if temp_dir and File.exists?(temp_dir)
      end
    else
      head :internal_server_error
    end
  end

  # Remove a plugin
  def destroy
    plugin = Cosmos::Store.instance.hget("DEFAULT__cosmos_plugins", params[:plugin])
    if plugin
      # Remove targets, tools, interfaces, routers, microservices related to this plugin
      STDOUT.puts "Removing plugin: #{params[:plugin]}"
      Cosmos::Store.instance.hdel("DEFAULT__cosmos_plugins", params[:plugin])
    else
      head :internal_server_error
    end
  end
end
