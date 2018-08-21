RSpec.describe PostTweetsWorker do
  let(:post) do
    Post.import(123,
                item_id: 'abc',
                feed_id: 1,
                content_text: 'Foo bar',
                url: 'https://example.com/abc')
  end

  let(:tweets) do
    [
      post.add_tweet(body: "ABC it's easy"),
      post.add_tweet(body: "It's like counting up to three"),
      post.add_tweet(body: 'Sing a simple melody')
    ]
  end
  let(:ids) { tweets.map(&:id) }

  it 'moves the tweets to the posted status' do
    subject.perform(ids)
    expect(tweets.each(&:refresh).map(&:status)).to all(eq 'POSTED')
  end
end
