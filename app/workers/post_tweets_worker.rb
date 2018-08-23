class PostTweetsWorker
  include Sidekiq::Worker

  attr_reader :tweets

  def perform(tweet_ids)
    # TODO: actually post the tweet

    @tweets = Tweet.where(id: tweet_ids)
    tweets.each do |tweet|
      next if tweet.status != 'DRAFT'
      tweet.update status: 'POSTED'
      broadcast tweet
    end
  end

  private

  def message_channel
    @message_channel ||= MessageQueue.conn.create_channel
  end

  def broadcast(tweet)
    x = message_channel.direct('events.posts')
    x.publish(Courier::PostTweet.encode(tweet.to_proto))
  end
end
