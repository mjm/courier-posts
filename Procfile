web: bundle exec rackup config.ru -p $PORT -s puma
worker: bundle exec sidekiq -c 5 -t 25 -r ./config/environment.rb -e $RACK_ENV
