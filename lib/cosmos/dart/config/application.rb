require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module CosmosDart
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    config.cache_store = :file_store, File.join(Cosmos::System.paths['TMP'], 'cache')
    config.assets.cache_store = :file_store, File.join(Cosmos::System.paths['TMP'], 'assets')
    config.sass.cache = false
    config.assets.cache_limit = 50.megabytes

    config.assets.configure do |env|
      env.cache = Sprockets::Cache::FileStore.new(
        File.join(Cosmos::System.paths['TMP'], 'cache', 'assets'),
        config.assets.cache_limit,
        env.logger
      )
    end

  end
end
