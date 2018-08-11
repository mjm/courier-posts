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
      subject.perform(post.id)
    end

    it 'creates a tweet for the post with the translated text' do
      subject.perform(post.id)
      expect(post.tweets.count).to eq 1
      expect(post.tweets.first).to have_attributes(
        body: 'This is a tweet'
      )
    end
  end

  context 'when the post already has a tweet' do
    before do
      post.add_tweet(body: 'Foo')
    end

    it 'does not create a new tweet' do
      expect { subject.perform(post.id) }
        .not_to(change { post.tweets(reload: true).count })
    end
  end
end
