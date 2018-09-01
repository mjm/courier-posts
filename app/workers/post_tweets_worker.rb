class PostTweetsWorker
  include Sidekiq::Worker

  attr_reader :tweets

  def perform(tweet_ids)
    @tweets = Tweet.where(id: tweet_ids)
    tweets.each do |tweet|
      next if tweet.status != 'DRAFT'

      resp = tweeter_client.post_tweet(user_id: tweet.post.user_id,
                                       body: tweet.body)

      tweet.update(
        status: 'POSTED',
        posted_at: Time.now,
        posted_tweet_id: resp.data.id
      )
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

  def tweeter_client
    @tweeter_client ||= Courier::TweeterClient.connect(
      token: Courier::Service::TOKEN
    )
  end
end
