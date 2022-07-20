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
require 'openc3/models/scope_model'
require 'openc3/utilities/s3'

module OpenC3
  class WidgetModel < Model
    PRIMARY_KEY = 'openc3_widgets'

    attr_accessor :name
    attr_accessor :full_name
    attr_accessor :filename
    attr_accessor :s3_key
    attr_accessor :needs_dependencies

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
        tools[key] = JSON.parse(value, :allow_nan => true, :create_additions => true)
      end
      return tools
    end

    def self.all_scopes
      result = {}
      scopes = OpenC3::ScopeModel.all
      scopes.each do |key, _scope|
        widgets = all(scope: key)
        result.merge!(widgets)
      end
      result
    end

    # Called by the PluginModel to allow this class to validate it's top-level keyword: "WIDGET"
    def self.handle_config(parser, keyword, parameters, plugin: nil, needs_dependencies: false, scope:)
      case keyword
      when 'WIDGET'
        parser.verify_num_parameters(1, 1, "WIDGET <Name>")
        return self.new(name: parameters[0], plugin: plugin, needs_dependencies: needs_dependencies, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Widget: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def initialize(
      name:,
      updated_at: nil,
      plugin: nil,
      needs_dependencies: false,
      scope:
    )
      super("#{scope}__#{PRIMARY_KEY}", name: name, plugin: plugin, updated_at: updated_at, scope: scope)
      @full_name = @name.capitalize + 'Widget'
      @filename = @full_name + '.umd.min.js'
      @s3_key = 'widgets/' + @full_name + '/' + @filename
      @needs_dependencies = needs_dependencies
    end

    def as_json(*a)
      {
        'name' => @name,
        'updated_at' => @updated_at,
        'plugin' => @plugin,
        'needs_dependencies' => @needs_dependencies,
      }
    end

    def as_config
      result = "WIDGET \"#{@name}\"\n"
      result
    end

    def handle_config(parser, keyword, parameters)
      raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Widget: #{keyword} #{parameters.join(" ")}")
    end

    def deploy(gem_path, variables, validate_only: false)
      # Ensure tools bucket exists
      OpenC3::S3Utilities.ensure_public_bucket('tools') unless validate_only

      filename = gem_path + "/tools/widgets/" + @full_name + '/' + @filename

      # Load widget file
      data = File.read(filename, mode: "rb")
      OpenC3.set_working_dir(File.dirname(filename)) do
        data = ERB.new(data, trim_mode: "-").result(binding.set_variables(variables)) if data.is_printable?
      end
      unless validate_only
        cache_control = OpenC3::S3Utilities.get_cache_control(@filename)
        # TODO: support widgets that aren't just a single js file (and its associated map file)
        rubys3_client = Aws::S3::Client.new
        rubys3_client.put_object(bucket: 'tools', content_type: 'application/javascript', cache_control: cache_control, key: @s3_key, body: data)
        data = File.read(filename + '.map', mode: "rb")
        rubys3_client.put_object(bucket: 'tools', content_type: 'application/json', cache_control: cache_control, key: @s3_key + '.map', body: data)
      end
    end

    def undeploy
      rubys3_client = Aws::S3::Client.new
      rubys3_client.delete_object(bucket: 'tools', key: @s3_key)
      rubys3_client.delete_object(bucket: 'tools', key: @s3_key + '.map')
    end
  end
end
