module Cosmos
  module Api
    WHITELIST ||= []
    WHITELIST.concat([
      'get_saved_config',
      'list_configs',
      'load_config',
      'save_config',
      'delete_config'
    ])

    # Get a saved configuration zip file
    def get_saved_config(configuration_name = nil, scope: $cosmos_scope, token: $cosmos_token)
      raise "Not supported by COSMOS 5"
    end

    def list_configs(tool, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hkeys("#{scope}__config__#{tool}")
    end

    def load_config(tool, name, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hget("#{scope}__config__#{tool}", name)
    end

    def save_config(tool, name, data, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hset("#{scope}__config__#{tool}", name, data)
    end

    def delete_config(tool, name, scope: $cosmos_scope, token: $cosmos_token)
      Store.instance.hdel("#{scope}__config__#{tool}", name)
    end
  end
end