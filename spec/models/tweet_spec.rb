RSpec.describe Tweet do
  describe '#to_proto' do
    let(:post) do
      Post.import(123,
                  feed_id: 1,
                  item_id: 'abc',
                  content_text: 'foo bar',
                  url: 'https://example.com/abc')
    end
    let(:posted_at) { Time.utc(2018, 6, 1) }
    let(:tweet) do
      post.add_tweet(body: 'foo bar',
                     status: 'POSTED',
                     posted_at: posted_at,
                     posted_tweet_id: '123456')
    end

    it 'converts the tweet to a protobuf message' do
      expect(tweet.to_proto).to eq Courier::PostTweet.new(
        id: tweet.id,
        post_id: post.id,
        body: 'foo bar',
        status: :POSTED,
        user_id: 123,
        posted_at: '2018-06-01T00:00:00Z',
        posted_tweet_id: '123456'
      )
    end
  end
end
