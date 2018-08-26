RSpec.describe Post do
  describe '#import' do
    subject do
      Post.import(123,
                  item_id: 'abc',
                  feed_id: 234,
                  content_html: '',
                  content_text: 'Foo',
                  title: '',
                  published_at: '2018-07-20T19:14:38+00:00',
                  modified_at: '2018-07-20T19:14:38+00:00',
                  url: 'https://example.com/abc',
                  autopost_delay: 300)
    end

    context 'when the post does not already exist' do
      it 'creates a new post' do
        expect { subject }.to change { Post.count }.by 1
      end

      it 'returns the created post' do
        expect(subject).to have_attributes(
          id: a_value > 0,
          item_id: 'abc',
          feed_id: 234,
          content_html: '',
          content_text: 'Foo',
          url: 'https://example.com/abc',
          published_at: Time,
          modified_at: Time,
          title: ''
        )
      end

      it 'enqueues a job to translate the post into a tweet' do
        post_id = subject.id
        expect(TranslateTweetWorker).to have_enqueued_sidekiq_job(post_id, 300)
      end
    end

    context 'when the post has been imported before' do
      let!(:post) do
        Post.import(123,
                    item_id: 'abc',
                    feed_id: 234,
                    content_text: 'Bar',
                    title: 'An old title',
                    url: 'https://example.com/123',
                    published_at: '2018-07-20T19:14:38+00:00',
                    modified_at: '2018-07-20T19:14:38+00:00')
      end

      it 'does not create a new post' do
        expect { subject }.not_to(change { Post.count })
      end

      it 'updates the attributes of the existing post' do
        subject
        expect(post.refresh).to have_attributes(
          content_text: 'Foo',
          title: '',
          url: 'https://example.com/abc'
        )
      end

      it 'does not update the created_at time' do
        expect { subject }.not_to(change do
          post.refresh.created_at
        end)
      end

      it 'returns the updated post' do
        expect(subject).to have_attributes(
          id: post.id,
          item_id: 'abc',
          feed_id: 234,
          content_html: '',
          content_text: 'Foo',
          url: 'https://example.com/abc',
          title: '',
          published_at: Time,
          modified_at: Time
        )
      end
    end
  end

  describe '#to_proto' do
    subject do
      Post.import(123,
                  item_id: 'abc',
                  feed_id: 234,
                  content_html: '<p>Foo</p>',
                  content_text: 'Foo',
                  title: 'A title',
                  url: 'https://example.com/abc',
                  published_at: '2018-07-20T19:14:38+00:00',
                  modified_at: '2018-07-20T19:14:38+00:00')
    end

    before do
      subject.add_tweet(body: 'Foo')
      subject.add_tweet(body: 'Bar')
    end

    it 'creates a protobuf object representing the post' do
      expect(subject.to_proto).to eq Courier::Post.new(
        id: subject.id,
        item_id: 'abc',
        feed_id: 234,
        content_html: '<p>Foo</p>',
        content_text: 'Foo',
        title: 'A title',
        url: 'https://example.com/abc',
        published_at: '2018-07-20T19:14:38Z',
        modified_at: '2018-07-20T19:14:38Z',
        tweets: [
          Courier::PostTweet.new(
            id: subject.tweets[0].id,
            post_id: subject.id,
            body: 'Foo',
            user_id: 123
          ),
          Courier::PostTweet.new(
            id: subject.tweets[1].id,
            post_id: subject.id,
            body: 'Bar',
            user_id: 123
          )
        ]
      )
    end
  end
end
