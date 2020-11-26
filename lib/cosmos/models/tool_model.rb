require 'cosmos/models/model'

module Cosmos
  class ToolModel < Model
    PRIMARY_KEY = 'cosmos_tools'

    def initialize(
      name:,
      folder_name: nil,
      icon: 'mdi-alert',
      url: nil,
      updated_at: nil,
      scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name, updated_at: updated_at)
      @folder_name = folder_name
      @icon = icon
      @url = url
    end

    def as_json
      {
        'name' => @name,
        'folder_name' => @folder_name,
        'icon' => @icon,
        'url' => @url,
        'updated_at' => @updated_at
      }
    end

    def as_config
      result = "TOOL #{@folder_name ? @folder_name : 'nil'} \"#{@name}\"\n"
      result << "  URL #{@url}\n"
      result << "  ICON #{@icon}\n"
      result
    end

    def self.handle_config(parser, keyword, parameters, scope:)
      case keyword
      when 'TOOL'
        parser.verify_num_parameters(2, 2, "TOOL <Folder Name> <Name>")
        return self.new(folder_name: parameters[0], name: parameters[1], scope: scope)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Tool: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def handle_config(parser, keyword, parameters, scope:)
      case keyword
      when 'URL'
        parser.verify_num_parameters(1, 1, "URL <URL>")
        @url = parameters[0]
      when 'ICON'
        parser.verify_num_parameters(1, 1, "ICON <ICON Name>")
        @icon = parameters[0]
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Tool: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def self.get(name:, scope: nil)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def self.names(scope: nil)
      super("#{scope}__#{PRIMARY_KEY}")
    end

    def self.all(scope: nil)
      tools = super("#{scope}__#{PRIMARY_KEY}")
      if tools.length < 1
        tools = {}
        tools['CmdTlmServer'] = {
          name: 'CmdTlmServer',
          icon: 'mdi-server-network',
          url: '/cmd-tlm-server'
        }
        tools['Limits Monitor'] = {
          name: 'Limits Monitor',
          icon: 'mdi-alert',
          url: '/limits-monitor'
        }
        tools['Command Sender'] = {
          name: 'Command Sender',
          icon: 'mdi-satellite-uplink',
          url: '/command-sender'
        }
        tools['Script Runner'] = {
          name: 'Script Runner',
          icon: 'mdi-run-fast',
          url: '/script-runner'
        }
        tools['Packet Viewer'] = {
          name: 'Packet Viewer',
          icon: 'mdi-format-list-bulleted',
          url: '/packet-viewer'
        }
        tools['Telemetry Viewer'] = {
          name: 'Telemetry Viewer',
          icon: 'mdi-monitor-dashboard',
          url: '/telemetry-viewer'
        }
        tools['Telemetry Grapher'] = {
          name: 'Telemetry Grapher',
          icon: 'mdi-chart-line',
          url: '/telemetry-grapher'
        }
        tools['Data Extractor'] = {
          name: 'Data Extractor',
          icon: 'mdi-archive-arrow-down',
          url: '/data-extractor'
        }
        tools.each do |name, tool|
          Store.hset("#{scope}__#{PRIMARY_KEY}", name, JSON.generate(tool))
        end
      end
      return tools
    end

    def deploy(gem_path, variables, scope:)
      variables["tool_name"] = @name
      rubys3_client = Aws::S3::Client.new
      start_path = "/tools/#{@folder_name}/"
      Dir.glob(gem_path + start_path + "**/*") do |filename|
        next if filename == '.' or filename == '..' or File.directory?(filename)
        path = filename.split(gem_path)[-1]
        key = "#{scope}/tools/#{@name}/" + path.split(start_path)[-1]

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
