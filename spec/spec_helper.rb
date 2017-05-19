require 'factory_girl'
require 'json_spec'
require 'rack/test'
require 'rspec'

ENV['RACK_ENV'] = 'test'

module RSpecMixin
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def xhr_post(url, opts = {}, session = {})
    post(url, opts.merge(xhr: true, as: :json), session)
  end

  def xhr_get(url, opts = {})
    get(url, opts.merge(xhr: true, as: :json))
  end

  def response_json
    JSON.parse(last_response.body)
  end
end

RSpec.configure do |config|
  config.include RSpecMixin
  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    FactoryGirl.definition_file_paths = %w{./factories ./test/factories ./spec/factories}
    FactoryGirl.find_definitions
  end
end