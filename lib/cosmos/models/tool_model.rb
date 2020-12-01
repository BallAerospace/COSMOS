require 'cosmos/models/model'

module Cosmos
  class ToolModel < Model
    PRIMARY_KEY = 'cosmos_tools'

    attr_accessor :folder_name
    attr_accessor :icon
    attr_accessor :url
    attr_accessor :position

    def initialize(
      name:,
      folder_name: nil,
      icon: 'mdi-alert',
      url: nil,
      position: nil,
      updated_at: nil,
      scope:)
      super("#{scope}__#{PRIMARY_KEY}", name: name, updated_at: updated_at)
      @folder_name = folder_name
      @icon = icon
      @url = url
      @position = position
    end

    def create(update: false, force: false)
      unless @position
        scope = @primary_key.split("__")[0]
        tools = self.class.all(scope: scope)
        max_position = nil
        tools.each do |tool_name, tool|
          max_position = tool['position'] if !max_position or tool['position'] > max_position
        end
        max_position ||= 0
        @position = max_position + 1
      end
      super(update: update, force: force)
    end

    def as_json
      {
        'name' => @name,
        'folder_name' => @folder_name,
        'icon' => @icon,
        'url' => @url,
        'position' => @position,
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
      array = []
      all(scope: scope).each do |name, tool|
        array << name
      end
      array
    end

    def self.all(scope: nil)
      ordered_array = []
      tools = unordered_all(scope: scope)
      tools.each do |name, tool|
        ordered_array << tool
      end
      ordered_array.sort! {|a,b| a['position'] <=> b['position']}
      ordered_hash = {}
      ordered_array.each do |tool|
        ordered_hash[tool['name']] = tool
      end
      ordered_hash
    end

    def self.unordered_all(scope: nil)
      tools = Store.hgetall("#{scope}__#{PRIMARY_KEY}")
      tools.each do |key, value|
        tools[key] = JSON.parse(value)
      end
      if tools.length < 1
        tools = {}
        tools['CmdTlmServer'] = {
          name: 'CmdTlmServer',
          icon: 'mdi-server-network',
          url: '/cmd-tlm-server',
          position: 1,
        }
        tools['Limits Monitor'] = {
          name: 'Limits Monitor',
          icon: 'mdi-alert',
          url: '/limits-monitor',
          position: 2,
        }
        tools['Command Sender'] = {
          name: 'Command Sender',
          icon: 'mdi-satellite-uplink',
          url: '/command-sender',
          position: 3,
        }
        tools['Script Runner'] = {
          name: 'Script Runner',
          icon: 'mdi-run-fast',
          url: '/script-runner',
          position: 4,
        }
        tools['Packet Viewer'] = {
          name: 'Packet Viewer',
          icon: 'mdi-format-list-bulleted',
          url: '/packet-viewer',
          position: 5,
        }
        tools['Telemetry Viewer'] = {
          name: 'Telemetry Viewer',
          icon: 'mdi-monitor-dashboard',
          url: '/telemetry-viewer',
          position: 6,
        }
        tools['Telemetry Grapher'] = {
          name: 'Telemetry Grapher',
          icon: 'mdi-chart-line',
          url: '/telemetry-grapher',
          position: 7,
        }
        tools['Data Extractor'] = {
          name: 'Data Extractor',
          icon: 'mdi-archive-arrow-down',
          url: '/data-extractor',
          position: 8,
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

    # Order is the position in the list starting with 0 = first
    def self.set_order(name:, order:, scope:)
      ordered = all(scope: scope)
      tool_model = from_json(ordered[name], scope: scope)
      index = 0
      previous_position = 0.0
      move_next = false
      tool_position = 0
      ordered.each do |tool_name, tool|
        tool_position = tool['position']
        if move_next or index == order
          # Need to take the position of this tool
          if move_next or tool_name != name
            if move_next or tool_model.position > tool_position
              new_position = (previous_position + tool_position) / 2.0
              tool_model.position = new_position
              tool_model.update
              return
            else
              move_next = true
            end
          end
        end
        previous_position = tool_position
        index += 1
      end
      if move_next
        new_position = previous_position + 1
        tool_model.position = new_position
        tool_model.update
      end
    end
  end
end
