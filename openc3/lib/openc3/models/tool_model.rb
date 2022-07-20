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

require 'openc3/models/model'
require 'openc3/models/scope_model'
require 'openc3/utilities/s3'
require 'rack'

module OpenC3
  class ToolModel < Model
    PRIMARY_KEY = 'openc3_tools'

    attr_accessor :folder_name
    attr_accessor :icon
    attr_accessor :url
    attr_accessor :inline_url
    attr_accessor :window
    attr_accessor :category
    attr_accessor :shown
    attr_accessor :position
    attr_accessor :needs_dependencies

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope: nil)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope: nil)
      array = []
      all(scope: scope).each do |name, _tool|
        array << name
      end
      array
    end

    def self.all(scope: nil)
      ordered_array = []
      tools = unordered_all(scope: scope)
      tools.each do |_name, tool|
        ordered_array << tool
      end
      ordered_array.sort! { |a, b| a['position'] <=> b['position'] }
      ordered_hash = {}
      ordered_array.each do |tool|
        ordered_hash[tool['name']] = tool
      end
      ordered_hash
    end

    def self.all_scopes
      result = {}
      scopes = OpenC3::ScopeModel.all
      scopes.each do |key, _scope|
        tools = unordered_all(scope: key)
        result.merge!(tools)
      end
      result
    end

    # Called by the PluginModel to allow this class to validate it's top-level keyword: "TOOL"
    def self.handle_config(parser, keyword, parameters, plugin: nil, needs_dependencies: false, scope:)
      case keyword
      when 'TOOL'
        parser.verify_num_parameters(2, 2, "TOOL <Folder Name> <Name>")
        return self.new(folder_name: parameters[0], name: parameters[1], plugin: plugin, needs_dependencies: needs_dependencies, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Tool: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    # The ToolsTab.vue calls the ToolsController which uses this method to reorder the tools
    # Position is index in the list starting with 0 = first
    def self.set_position(name:, position:, scope:)
      position = Integer(position)
      next_position = position + 1

      # Go through all the tools and reorder
      all(scope: scope).each do |_tool_name, tool|
        tool_model = from_json(tool, scope: scope)
        # Update the requested model to the new position
        if tool_model.name == name
          tool_model.position = position
        # Move existing tools down in the order
        elsif position > 0 && position >= tool_model.position
          tool_model.position -= 1
        else # Move existing tools up in the order
          tool_model.position = next_position
          next_position += 1
        end
        tool_model.update
      end
    end

    def initialize(
      name:,
      folder_name: nil,
      icon: '$astro-caution',
      url: nil,
      inline_url: nil,
      window: 'INLINE',
      category: nil,
      shown: true,
      position: nil,
      updated_at: nil,
      plugin: nil,
      needs_dependencies: false,
      scope:
    )
      super("#{scope}__#{PRIMARY_KEY}", name: name, plugin: plugin, updated_at: updated_at, scope: scope)
      @folder_name = folder_name
      @icon = icon
      @url = url
      @inline_url = inline_url
      @window = window.to_s.upcase
      @category = category
      @shown = shown
      @position = position

      if @shown and @window == 'INLINE'
        @inline_url = 'js/app.js' unless @inline_url
        @url = "/tools/#{folder_name}" unless @url
      end
      @needs_dependencies = needs_dependencies
    end

    def create(update: false, force: false)
      unless @position
        tools = self.class.all(scope: @scope)
        _, tool = tools.max_by { |_tool_name, tool| tool['position'] }
        if tool
          @position = tool['position'] + 1
        else
          @position = 0
        end
      end
      super(update: update, force: force)
    end

    def as_json(*a)
      {
        'name' => @name,
        'folder_name' => @folder_name,
        'icon' => @icon,
        'url' => @url,
        'inline_url' => @inline_url,
        'window' => @window,
        'category' => @category,
        'shown' => @shown,
        'position' => @position,
        'updated_at' => @updated_at,
        'plugin' => @plugin,
        'needs_dependencies' => @needs_dependencies,
      }
    end

    def as_config
      result = "TOOL #{@folder_name ? @folder_name : 'nil'} \"#{@name}\"\n"
      result << "  URL #{@url}\n" if @url
      result << "  INLINE_URL #{@inline_url}\n" if @inline_url
      result << "  ICON #{@icon}\n" if @icon
      result << "  WINDOW #{@window}\n" unless @window == 'INLINE'
      result << "  CATEGORY #{@category}\n" if @category
      result << "  SHOWN false\n" unless @shown
      result
    end

    def handle_config(parser, keyword, parameters)
      case keyword
      when 'URL'
        parser.verify_num_parameters(1, 1, "URL <URL>")
        @url = parameters[0]
      when 'INLINE_URL'
        parser.verify_num_parameters(1, 1, "INLINE_URL <URL>")
        @inline_url = parameters[0]
      when 'ICON'
        parser.verify_num_parameters(1, 1, "ICON <ICON Name>")
        @icon = parameters[0]
      when 'WINDOW'
        parser.verify_num_parameters(1, 1, "WINDOW <INLINE | IFRAME | NEW>")
        @window = parameters[0].to_s.upcase
        raise ConfigParser::Error.new(parser, "Invalid WINDOW setting: #{@window}") unless ['INLINE', 'IFRAME', 'NEW'].include?(@window)
      when 'CATEGORY'
        parser.verify_num_parameters(1, 1, "CATEGORY <Category Name>")
        @category = parameters[0].to_s
      when 'SHOWN'
        parser.verify_num_parameters(1, 1, "SHOWN <true/false>")
        @shown = ConfigParser.handle_true_false(parameters[0])
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Tool: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def deploy(gem_path, variables, validate_only: false)
      return unless @folder_name

      # Ensure tools bucket exists
      OpenC3::S3Utilities.ensure_public_bucket('tools') unless validate_only

      variables["tool_name"] = @name
      start_path = "/tools/#{@folder_name}/"
      Dir.glob(gem_path + start_path + "**/*") do |filename|
        next if filename == '.' or filename == '..' or File.directory?(filename)

        key = filename.split(gem_path + '/tools/')[-1]
        extension = filename.split('.')[-1]
        content_type = Rack::Mime.mime_type(".#{extension}")

        # Load tool files
        data = File.read(filename, mode: "rb")
        data = ERB.new(data, trim_mode: "-").result(binding.set_variables(variables)) if data.is_printable?
        unless validate_only
          cache_control = OpenC3::S3Utilities.get_cache_control(filename)
          Aws::S3::Client.new.put_object(bucket: 'tools', content_type: content_type, cache_control: cache_control, key: key, body: data)
          ConfigTopic.write({ kind: 'created', type: 'tool', name: @folder_name, plugin: @plugin }, scope: @scope)
        end
      end
    end

    def undeploy
      if @folder_name and @folder_name.to_s.length > 0
        rubys3_client = Aws::S3::Client.new
        prefix = "#{@folder_name}/"
        rubys3_client.list_objects(bucket: 'tools', prefix: prefix).contents.each do |object|
          rubys3_client.delete_object(bucket: 'tools', key: object.key)
          ConfigTopic.write({ kind: 'deleted', type: 'tool', name: @folder_name, plugin: @plugin }, scope: @scope)
        end
      end
    end

    ##################################################
    # The following methods are implementation details
    ##################################################

    # Returns the list of tools or the default OpenC3 tool set if no tools have been created
    def self.unordered_all(scope: nil)
      tools = Store.hgetall("#{scope}__#{PRIMARY_KEY}")
      tools.each do |key, value|
        tools[key] = JSON.parse(value, :allow_nan => true, :create_additions => true)
      end
      return tools
    end
  end
end
