require 'cosmos/models/model'

module Cosmos
  class ToolModel < Model
    PRIMARY_KEY = 'cosmos_tools'

    def initialize(
      name:,
      icon:,
      url:,
      scope: nil)
      super("#{scope}__#{PRIMARY_KEY}", name: name)
    end

    def as_json
      {
        'name' => @name,
        'icon' => @icon,
        'url' => @url
      }
    end

    def as_config
      "TOOL #{@name} #{@icon} \"#{@url}\"\n"
    end

    def self.handle_config(primary_key, parser, model, keyword, parameters)
      case keyword
      when 'TOOL'
        parser.verify_num_parameters(3, 3, "TOOL <Name> <Icon> <Url>")
        return self.new(name: parameters[0], icon: parameters[1], url: parameters[2].remove_quotes)
      else
        raise ConfigParser::Error.new(parser, "Unknown keyword and parameters for Tool: #{keyword} #{parameters.join(" ")}")
      end
      return nil
    end

    def self.from_json(json, scope: nil)
      json = JSON.parse(json) if String === json
      self.new("#{scope}__#{PRIMARY_KEY}", **json)
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
  end
end