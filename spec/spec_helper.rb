require 'bundler/setup'
require 'base64'
require 'courier/rspec'

ENV['RACK_ENV'] = 'test'
ENV['DATABASE_URL'] = 'postgres:///courier_posts_test'
ENV['JWT_SECRET'] = Base64.encode64(Random.new.bytes(32))
ENV['SESSION_SECRET'] = 'super secret'

$LOAD_PATH.unshift File.expand_path(File.join(__dir__, '..'))
require 'config/environment'
require 'app'

# DB.logger = Logger.new($stdout)

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.extend Courier::RPCHelpers, rpc: true

  config.around(:each) do |example|
    DB.transaction(rollback: :always, auto_savepoint: true) do
      example.run
    end
  end

  config.before(:each) do
    MessageQueue.conn = BunnyMock.new.start
  end
end
