class ToolsController < ApplicationController
  # List the available tools
  def index
    tools = Cosmos::Store.instance.get_tools(scope: params[:scope])
    if tools.length < 1
      tools = []
      tools << {
        name: 'CmdTlmServer',
        icon: 'mdi-server-network',
        url: '/cmd-tlm-server'
      }
      tools << {
        name: 'Limits Monitor',
        icon: 'mdi-alert',
        url: '/limits-monitor'
      }
      tools << {
        name: 'Command Sender',
        icon: 'mdi-satellite-uplink',
        url: '/command-sender'
      }
      tools << {
        name: 'Script Runner',
        icon: 'mdi-run-fast',
        url: '/script-runner'
      }
      tools << {
        name: 'Packet Viewer',
        icon: 'mdi-format-list-bulleted',
        url: '/packet-viewer'
      }
      tools << {
        name: 'Telemetry Viewer',
        icon: 'mdi-monitor-dashboard',
        url: '/telemetry-viewer'
      }
      tools << {
        name: 'Telemetry Grapher',
        icon: 'mdi-chart-line',
        url: '/telemetry-grapher'
      }
      tools << {
        name: 'Data Extractor',
        icon: 'mdi-archive-arrow-down',
        url: '/data-extractor'
      }
      tools.each do |tool|
        data = {}
        data[:icon] = tool[:icon]
        data[:url] = tool[:url]
        Cosmos::Store.instance.set_tool(tool[:name], data, scope: params[:scope])
      end
    end

    render :json => tools
  end

  # Add a new tool
  def create
    if params[:name] and params[:data] and params[:scope]
      Cosmos::Store.instance.set_tool(params[:name], params[:data], scope: params[:scope])
    else
      head :internal_server_error
    end
  end

  # Remove a tool
  def destroy
    if params[:scope] and params[:name]
      Cosmos::Store.instance.remove_tool(params[:name], scope: params[:scope])
    else
      head :internal_server_error
    end
  end
end
