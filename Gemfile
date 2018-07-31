source 'https://rubygems.org'
ruby '2.5.1'

git_source(:github) { |repo_name| "https://github.com/#{repo_name}" }

gem 'courier-service', github: 'mjm/courier-service'
gem 'courier-translator', github: 'mjm/courier-translator', glob: 'client/*.gemspec'
gem 'jwt'
gem 'pg'
gem 'puma'
gem 'rack'
gem 'rake', '~> 10.0'
gem 'sequel'
gem 'sidekiq'
gem 'twirp'

group :development do
  gem 'pry'
end

group :test do
  gem 'rspec', '~> 3.0'
  gem 'rspec-sidekiq'
  gem 'webmock', require: 'webmock/rspec'
end
