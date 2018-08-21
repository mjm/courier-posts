class PostTweetsWorker
  include Sidekiq::Worker

  attr_reader :tweets

  def perform(tweet_ids)
    # TODO: actually post the tweet

    @tweets = Tweet.where(id: tweet_ids)
    tweets.each do |tweet|
      tweet.update status: 'POSTED'
    end
  end
end
