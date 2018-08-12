RACK_ENV = (ENV['RACK_ENV'] || 'development').to_sym
Bundler.require(:default, RACK_ENV)

Courier::Service.configure do
  root __dir__, '..'

  database
  background_jobs
end

Sequel.default_timezone = :utc
DB.extension :pg_enum
