$LOAD_PATH.unshift(File.expand_path('../../lib', __dir__))
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

require 'concurrent-ruby'
require 'rails'
require 'action_controller/railtie'
require 'json'
require_relative '../lib/commerce_store'
require_relative '../lib/commerce_agent'

module CommerceCopilot
  class Application < Rails::Application
    config.load_defaults 8.1
    config.eager_load = false
    config.secret_key_base = ENV.fetch('SECRET_KEY_BASE', 'local-commerce-copilot')
    config.logger = Logger.new(nil)
    config.hosts.clear
    config.root = File.expand_path('..', __dir__)
  end
end
