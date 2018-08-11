class TranslateTweetWorker
  include Sidekiq::Worker

  attr_reader :post

  def perform(post_id)
    @post = Post[post_id]
    return unless post.tweets.empty?

    response = translator_client.translate(content_html: post.content_html)
    response.data.tweets.each do |tweet|
      post.add_tweet(body: tweet.body)
    end
  end

  private

  def translator_client
    @translator_client ||= Courier::TranslatorClient.connect
  end
end
