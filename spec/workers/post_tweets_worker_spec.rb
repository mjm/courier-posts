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

  let(:channel) { MessageQueue.conn.create_channel }
  let(:exchange) { channel.direct('events.posts') }
  let(:queue) do
    channel.queue('', exclusive: true).bind(exchange)
  end

  it 'sends the updated tweets to the message broker' do
    queue # the queue needs to exist before the message is sent
    subject.perform(ids)
    messages = queue.all.map { |payload| payload[:message] }
    expect(messages.size).to eq 3
    expect(messages.map { |m| Courier::PostTweet.decode(m) }).to all(be_a(Courier::PostTweet))
  end

  context 'when the tweet is canceled' do
    before do
      tweets.first.tap do |t|
        t.update status: 'CANCELED'
        t.refresh
      end
    end

    it 'does not update the status of the canceled tweet' do
      subject.perform(ids)
      expect(tweets.first.refresh.status).to eq 'CANCELED'
    end
  end

  context 'when the tweet is already posted' do
    before do
      tweets.first.tap do |t|
        t.update status: 'POSTED'
        t.refresh
      end
    end

    # I know this is kind of trivial. We'll have a better way to check this
    # when the real work is happening.
    it 'does not update the status of the canceled tweet' do
      subject.perform(ids)
      expect(tweets.first.refresh.status).to eq 'POSTED'
    end
  end
end
