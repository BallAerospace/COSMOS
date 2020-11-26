require 'cosmos/models/model'

module Cosmos
  class MicroserviceModel < Model
    PRIMARY_KEY = 'cosmos_microservices'

    attr_accessor :cmd
    attr_accessor :options

    def initialize(
      name:,
      folder_name: nil,
      cmd: [],
      work_dir: '.',
      env: {},
      topics: [],
      target_names: [],
      options: [],
      container: "cosmos-base",
      updated_at: nil,
      scope:)
      super(PRIMARY_KEY, name: name, updated_at: updated_at)
      @folder_name = folder_name
      @cmd = cmd
      @work_dir = work_dir
      @env = env
      @topics = topics
      @target_names = target_names
      @options = options
      @container = container
    end

    def as_json
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
        'updated_at' => @updated_at
      }
    end

    def as_config
      result = "MICROSERVICE #{@folder_name ? @folder_name : 'nil'} #{@name}\n"
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
      result << "  CONTAINER #{@container}\n" if @container != 'cosmos-base'
      result
    end


    def self.handle_config(parser, keyword, parameters, scope:)
      case keyword
      when 'MICROSERVICE'
        parser.verify_num_parameters(2, 2, "#{keyword} <Folder Name> <Name>")
        return self.new(folder_name: parameters[0], name: "#{scope}__#{parameters[1]}", scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Microservice: #{keyword} #{parameters.join(" ")}")
      end
    end

    def handle_config(parser, keyword, parameters, scope:)
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
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Microservice: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def self.get(name:, scope: nil)
      super(PRIMARY_KEY, name: name)
    end

    def self.names(scope: nil)
      super(PRIMARY_KEY)
    end

    def self.all(scope: nil)
      super(PRIMARY_KEY)
    end

    def deploy(gem_path, variables, scope:)
      if @folder_name
        variables["microservice_name"] = @name
        rubys3_client = Aws::S3::Client.new
        start_path = "/microservices/#{@folder_name}/"
        Dir.glob(gem_path + start_path + "**/*") do |filename|
          next if filename == '.' or filename == '..' or File.directory?(filename)
          path = filename.split(gem_path)[-1]
          key = "#{scope}/microservices/#{@name}/" + path.split(start_path)[-1]

          # Load target files
          data = File.read(filename, mode: "rb")
          if data.is_printable?
            rubys3_client.put_object(bucket: 'config', key: key, body: ERB.new(data).result(create_erb_binding(variables)))
          else
            rubys3_client.put_object(bucket: 'config', key: key, body: data)
          end
        end
      end
    end
  end
end