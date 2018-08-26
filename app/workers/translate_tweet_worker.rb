class TranslateTweetWorker
  include Sidekiq::Worker

  attr_reader :post

  def perform(post_id, autopost_delay)
    @post = Post[post_id]
    return unless post.tweets.empty?

    response = translator_client.translate(content_html: post.content_html)
    created_tweets = response.data.tweets.map do |tweet|
      post.add_tweet(body: tweet.body)
    end

    if autopost_delay > 0
      PostTweetsWorker.perform_in(autopost_delay, created_tweets.map(&:id))
    end
  end

  private

  def translator_client
    @translator_client ||= Courier::TranslatorClient.connect
  end
end
