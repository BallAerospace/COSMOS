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
require 'cosmos/models/scope_model'
require 'cosmos/utilities/s3'

module Cosmos
  class WidgetModel < Model
    PRIMARY_KEY = 'cosmos_widgets'

    attr_accessor :name
    attr_accessor :full_name
    attr_accessor :filename
    attr_accessor :s3_key

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope: nil)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope: nil)
      array = []
      all(scope: scope).each do |name, _widget|
        array << name
      end
      array
    end

    def self.all(scope: nil)
      tools = Store.hgetall("#{scope}__#{PRIMARY_KEY}")
      tools.each do |key, value|
        tools[key] = JSON.parse(value)
      end
      return tools
    end

    def self.all_scopes
      result = {}
      scopes = Cosmos::ScopeModel.all
      scopes.each do |key, _scope|
        widgets = all(scope: key)
        result.merge!(widgets)
      end
      result
    end

    # Called by the PluginModel to allow this class to validate it's top-level keyword: "WIDGET"
    def self.handle_config(parser, keyword, parameters, plugin: nil, scope:)
      case keyword
      when 'WIDGET'
        parser.verify_num_parameters(1, 1, "WIDGET <Name>")
        return self.new(name: parameters[0], plugin: plugin, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Widget: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def initialize(
      name:,
      updated_at: nil,
      plugin: nil,
      scope:
    )
      super("#{scope}__#{PRIMARY_KEY}", name: name, plugin: plugin, updated_at: updated_at, scope: scope)
      @full_name = @name.capitalize + 'Widget'
      @filename = @full_name + '.umd.min.js'
      @s3_key = 'widgets/' + @full_name + '/' + @filename
    end

    def as_json
      {
        'name' => @name,
        'updated_at' => @updated_at,
        'plugin' => @plugin
      }
    end

    def as_config
      result = "WIDGET \"#{@name}\"\n"
      result
    end

    def handle_config(parser, keyword, parameters)
      raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Widget: #{keyword} #{parameters.join(" ")}")
    end

    def deploy(gem_path, variables)
      rubys3_client = Aws::S3::Client.new

      # Ensure tools bucket exists
      Cosmos::S3Utilities.ensure_public_bucket('tools')

      filename = gem_path + "/tools/widgets/" + @full_name + '/' + @filename

      cache_control = 'no-cache'
      # Allow caching for files that have a filename versioning strategy
      has_version_number = /(-|_|\.)\d+(-|_|\.)\d+(-|_|\.)\d+\./.match(@filename)
      has_content_hash = /\.[a-f0-9]{20}\./.match(@filename)
      cache_control = nil if has_version_number or has_content_hash

      # Load widget file
      data = File.read(filename, mode: "rb")
      data = ERB.new(data).result(binding.set_variables(variables)) if data.is_printable?
      # TODO: support widgets that aren't just a single js file (and its associated map file)
      rubys3_client.put_object(bucket: 'tools', content_type: 'application/javascript', cache_control: cache_control, key: @s3_key, body: data)
      data = File.read(filename + '.map', mode: "rb")
      rubys3_client.put_object(bucket: 'tools', content_type: 'application/json', cache_control: cache_control, key: @s3_key + '.map', body: data)
    end

    def undeploy
      rubys3_client = Aws::S3::Client.new
      rubys3_client.delete_object(bucket: 'tools', key: @s3_key)
      rubys3_client.delete_object(bucket: 'tools', key: @s3_key + '.map')
    end
  end
end
