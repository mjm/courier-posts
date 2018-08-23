RACK_ENV = (ENV['RACK_ENV'] || 'development').to_sym
Bundler.require(:default, RACK_ENV)

Courier::Service.configure do
  root __dir__, '..'

  database
  background_jobs
end

Sequel.default_timezone = :utc
DB.extension :pg_enum

MessageQueue = Struct.new(:conn).new
unless RACK_ENV == :test
  MessageQueue.conn = Bunny.new ENV['CLOUDAMQP_URL']
  MessageQueue.conn.start
end
