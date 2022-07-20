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
require 'openc3/utilities/s3'

module OpenC3
  class MicroserviceModel < Model
    PRIMARY_KEY = 'openc3_microservices'

    attr_accessor :cmd
    attr_accessor :options
    attr_accessor :needs_dependencies

    # NOTE: The following three class methods are used by the ModelController
    # and are reimplemented to enable various Model class methods to work
    def self.get(name:, scope: nil)
      super(PRIMARY_KEY, name: name)
    end

    def self.names(scope: nil)
      scoped = []
      unscoped = super(PRIMARY_KEY)
      unscoped.each do |name|
        if !scope or name.split("__")[0] == scope
          scoped << name
        end
      end
      scoped
    end

    def self.all(scope: nil)
      scoped = {}
      unscoped = super(PRIMARY_KEY)
      unscoped.each do |name, json|
        if !scope or name.split("__")[0] == scope
          scoped[name] = json
        end
      end
      scoped
    end

    # Called by the PluginModel to allow this class to validate it's top-level keyword: "MICROSERVICE"
    def self.handle_config(parser, keyword, parameters, plugin: nil, needs_dependencies: false, scope:)
      case keyword
      when 'MICROSERVICE'
        parser.verify_num_parameters(2, 2, "#{keyword} <Folder Name> <Name>")
        # Create name by adding scope and type 'USER' to indicate where this microservice came from
        return self.new(folder_name: parameters[0], name: "#{scope}__USER__#{parameters[1].upcase}", plugin: plugin, needs_dependencies: needs_dependencies, scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Microservice: #{keyword} #{parameters.join(" ")}")
      end
    end

    # Create a microservice model to be deployed to S3
    def initialize(
      name:,
      folder_name: nil,
      cmd: [],
      work_dir: '.',
      env: {},
      topics: [],
      target_names: [],
      options: [],
      container: nil,
      updated_at: nil,
      plugin: nil,
      needs_dependencies: false,
      scope:
    )
      parts = name.split("__")
      if parts.length != 3
        raise "name '#{name}' must be formatted as SCOPE__TYPE__NAME"
      end
      if parts[0] != scope
        raise "name '#{name}' scope '#{parts[0]}' doesn't match scope parameter '#{scope}'"
      end

      super(PRIMARY_KEY, name: name, updated_at: updated_at, plugin: plugin, scope: scope)
      @folder_name = folder_name
      @cmd = cmd
      @work_dir = work_dir
      @env = env
      @topics = topics
      @target_names = target_names
      @options = options
      @container = container
      @needs_dependencies = needs_dependencies
    end

    def as_json(*a)
      {
        'name' => @name,
        'folder_name' => @folder_name,
        'cmd' => @cmd,
        'work_dir' => @work_dir,
        'env' => @env,
        'topics' => @topics,
        'target_names' => @target_names,
        'options' => @options,
        'container' => @container,
        'updated_at' => @updated_at,
        'plugin' => @plugin,
        'needs_dependencies' => @needs_dependencies,
      }
    end

    def as_config
      result = "MICROSERVICE #{@folder_name ? @folder_name : 'nil'} #{@name.split("__")[-1]}\n"
      result << "  CMD #{@cmd.join(' ')}\n"
      result << "  WORK_DIR \"#{@work_dir}\"\n"
      @topics.each do |topic_name|
        result << "  TOPIC #{topic_name}\n"
      end
      @target_names.each do |target_name|
        result << "  TARGET_NAME #{target_name}\n"
      end
      @env.each do |key, value|
        result << "  ENV #{key} \"#{value}\"\n"
      end
      @options.each do |option|
        result << "  OPTION #{option.join(" ")}\n"
      end
      result << "  CONTAINER #{@container}\n" if @container != 'openc3-base'
      result
    end

    def handle_config(parser, keyword, parameters)
      case keyword
      when 'ENV'
        parser.verify_num_parameters(2, 2, "#{keyword} <Key> <Value>")
        @env[parameters[0]] = parameters[1]
      when 'WORK_DIR'
        parser.verify_num_parameters(1, 1, "#{keyword} <Dir>")
        @work_dir = parameters[0]
      when 'TOPIC'
        parser.verify_num_parameters(1, 1, "#{keyword} <Topic Name>")
        @topics << parameters[0]
      when 'TARGET_NAME'
        parser.verify_num_parameters(1, 1, "#{keyword} <Target Name>")
        @target_names << parameters[0]
      when 'CMD'
        parser.verify_num_parameters(1, nil, "#{keyword} <Args>")
        @cmd = parameters.dup
      when 'OPTION'
        parser.verify_num_parameters(2, nil, "#{keyword} <Option Name> <Option Values>")
        @options << parameters.dup
      when 'CONTAINER'
        parser.verify_num_parameters(1, 1, "#{keyword} <Container Image Name>")
        @container = parameters[0]
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Microservice: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def deploy(gem_path, variables, validate_only: false)
      return unless @folder_name

      variables["microservice_name"] = @name
      start_path = "/microservices/#{@folder_name}/"
      Dir.glob(gem_path + start_path + "**/*") do |filename|
        next if filename == '.' or filename == '..' or File.directory?(filename)

        path = filename.split(gem_path)[-1]
        key = "#{@scope}/microservices/#{@name}/" + path.split(start_path)[-1]

        # Load microservice files
        data = File.read(filename, mode: "rb")
        OpenC3.set_working_dir(File.dirname(filename)) do
          data = ERB.new(data, trim_mode: "-").result(binding.set_variables(variables)) if data.is_printable?
        end
        unless validate_only
          Aws::S3::Client.new.put_object(bucket: 'config', key: key, body: data)
          ConfigTopic.write({ kind: 'created', type: 'microservice', name: @name, plugin: @plugin }, scope: @scope)
        end
      end
    end

    def undeploy
      rubys3_client = Aws::S3::Client.new
      prefix = "#{@scope}/microservices/#{@name}/"
      rubys3_client.list_objects(bucket: 'config', prefix: prefix).contents.each do |object|
        rubys3_client.delete_object(bucket: 'config', key: object.key)
      end
      ConfigTopic.write({ kind: 'deleted', type: 'microservice', name: @name, plugin: @plugin }, scope: @scope)
    end
  end
end
