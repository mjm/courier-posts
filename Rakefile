require 'logger'
require 'courier/rake_tasks'

begin
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError # rubocop:disable Lint/HandleExceptions
end

task default: :spec

# Copied from Sequel's docs
# http://sequel.jeremyevans.net/rdoc/files/doc/migration_rdoc.html#label-Running+migrations+from+a+Rake+task
namespace :db do
  desc 'Run migrations'
  task :migrate, [:version] do |_, args|
    require 'sequel/core'
    Sequel.extension :migration
    version = args[:version].to_i if args[:version]
    url = ENV.fetch('DATABASE_URL')
    Sequel.connect(url, logger: Logger.new($stderr)) do |db|
      Sequel::Migrator.run(db, 'db/migrations', target: version)
    end
  end
end
