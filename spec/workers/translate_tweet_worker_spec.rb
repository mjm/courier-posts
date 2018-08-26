RSpec.describe TranslateTweetWorker do
  let(:tweets) { Courier::TranslatedTweetList.new(tweets: [tweet]) }
  let(:tweet) { Courier::TranslatedTweet.new(body: 'This is a tweet') }
  let(:response) { double(data: tweets) }
  let(:translator) { instance_double(Courier::TranslatorClient) }
  before do
    allow(Courier::TranslatorClient).to receive(:connect) { translator }
    allow(translator).to receive(:translate) { response }
  end

  let!(:post) do
    Post.import(123,
                item_id: 'abc', feed_id: 1,
                content_html: '<p>This is a tweet</p>',
                url: 'https://example.com/abc')
  end

  context 'when the post does not have any tweets' do
    it 'asks the translator service for the tweet text' do
      expect(translator).to receive(:translate)
        .with(content_html: '<p>This is a tweet</p>')
      subject.perform(post.id, 300)
    end

    it 'creates a tweet for the post with the translated text' do
      subject.perform(post.id, 300)
      expect(post.tweets.count).to eq 1
      expect(post.tweets.first).to have_attributes(
        body: 'This is a tweet'
      )
    end

    it 'enqueues a job to post the tweet in the specified time' do
      subject.perform(post.id, 300)
      tweet_id = post.tweets.first.id
      expect(PostTweetsWorker).to have_enqueued_sidekiq_job([tweet_id])
      # TODO: test the timing once I find a non-buggy way to do it
    end

    context 'when the post should not be autoposted' do
      it 'does not enqueue a job to post the tweet' do
        subject.perform(post.id, 0)
        tweet_id = post.tweets.first.id
        expect(PostTweetsWorker).not_to have_enqueued_sidekiq_job([tweet_id])
      end
    end
  end

  context 'when the post already has a tweet' do
    before do
      post.add_tweet(body: 'Foo')
    end

    it 'does not create a new tweet' do
      expect { subject.perform(post.id, 300) }
        .not_to(change { post.tweets(reload: true).count })
    end
  end
end
