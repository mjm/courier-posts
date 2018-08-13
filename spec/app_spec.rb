require 'shared_examples'

RSpec.describe PostsHandler do
  subject { App }

  Token = Courier::Middleware::JWTToken
  let(:token) { Token.new('sub' => 'example', 'uid' => 123) }
  let(:other_token) { Token.new('sub' => 'example2', 'uid' => 124) }
  let(:env) { {} }

  describe '#get_user_posts' do
    let(:request) { { user_id: 123 } }
    let(:response) { subject.call_rpc(:GetUserPosts, request, env) }

    include_examples 'an unauthenticated request'
    include_examples 'a request from another user'

    context 'when an auth token is provided' do
      context 'and the token matches the user whose posts were requested' do
        let(:env) { { token: token } }
        let(:posts) { response.posts }

        context 'when there are no posts' do
          it 'returns an empty list of posts' do
            expect(posts).to eq []
          end
        end

        context 'when there are some posts' do
          before do
            Post.create(user_id: 123, item_id: '123', feed_id: 1, content_text: 'Foo', url: 'https://example.com/123', published_at: '2018-07-20T19:14:38+00:00', modified_at: '2018-07-20T19:14:38+00:00')
            Post.create(user_id: 123, item_id: '234', feed_id: 1, content_html: '<p>Foo</p>', url: 'https://example.com/234', published_at: '2018-07-20T18:14:38+00:00', modified_at: '2018-07-21T19:14:38+00:00')
            Post.create(user_id: 234, item_id: '234', feed_id: 1, content_text: 'Foo', url: 'https://example.com/234')
          end

          it 'returns a list of the posts for the user in the reverse order of when they were published' do
            expect(posts.map(&:to_h)).to match [
              {
                id: a_value > 0,
                item_id: '123',
                feed_id: 1,
                content_html: '',
                content_text: 'Foo',
                url: 'https://example.com/123',
                title: '',
                published_at: String,
                modified_at: String,
                tweets: []
              },
              {
                id: a_value > 0,
                item_id: '234',
                feed_id: 1,
                content_html: '<p>Foo</p>',
                content_text: '',
                url: 'https://example.com/234',
                title: '',
                published_at: String,
                modified_at: String,
                tweets: []
              }
            ]
          end
        end
      end
    end
  end

  describe '#get_post' do
    let(:post) do
      Post.import(
        123,
        item_id: 'abc',
        feed_id: 234,
        content_text: 'Bar',
        title: 'An old title',
        url: 'https://example.com/123',
        published_at: '2018-07-20T19:14:38+00:00',
        modified_at: '2018-07-20T19:14:38+00:00'
      )
    end
    let(:request) { { id: post.id } }
    let(:response) { subject.call_rpc(:GetPost, request, env) }

    include_examples 'an unauthenticated request'

    context 'when an auth token for a different user is provided' do
      let(:env) { { token: other_token } }

      it 'returns a not found error' do
        expect(response).to be_a_twirp_error :not_found
      end
    end

    context 'when the post does not exist' do
      let(:env) { { token: token } }
      let(:request) { { id: post.id + 1 } }

      it 'returns a not found error' do
        expect(response).to be_a_twirp_error :not_found
      end
    end

    context 'when an auth token matching the post is provided' do
      let(:env) { { token: token } }

      it 'returns a description of the post' do
        expect(response).to eq Courier::Post.new(
          id: post.id,
          item_id: 'abc',
          feed_id: 234,
          content_text: 'Bar',
          title: 'An old title',
          url: 'https://example.com/123',
          published_at: '2018-07-20T19:14:38Z',
          modified_at: '2018-07-20T19:14:38Z'
        )
      end
    end
  end

  describe '#import_post' do
    let(:request) do
      {
        user_id: 123,
        post: Courier::Post.new(
          item_id: 'abc',
          feed_id: 234,
          content_text: 'Foo',
          url: 'https://example.com/abc',
          published_at: '2018-07-20T19:14:38+00:00',
          modified_at: '2018-07-20T19:14:38+00:00'
        )
      }
    end
    let(:response) { subject.call_rpc(:ImportPost, request, env) }

    include_examples 'an unauthenticated request'
    include_examples 'a request from another user'

    context 'when an auth token is provided' do
      context 'and the auth token is for another microservice' do
        let(:token) { Token.new('sub' => 'courier-feeds', 'roles' => ['service']) }
        let(:env) { { token: token } }

        it 'returns a successful response' do
          expect(response).not_to be_a_twirp_error :permission_denied
        end
      end

      context 'and the token matches the user id in the request' do
        let(:env) { { token: token } }

        it 'returns a successful response' do
          expect(response).not_to be_a_twirp_error
        end

        context 'when the post does not already exist' do
          it 'creates a new post' do
            expect { response }.to change { Post.count }.by 1
          end

          it 'returns a description of the imported post' do
            expect(response.to_h).to match(
              id: a_value > 0,
              item_id: 'abc',
              feed_id: 234,
              content_html: '',
              content_text: 'Foo',
              url: 'https://example.com/abc',
              title: '',
              published_at: '2018-07-20T19:14:38Z',
              modified_at: '2018-07-20T19:14:38Z',
              tweets: []
            )
          end

          it 'enqueues a job to translate the post into a tweet' do
            post_id = response.id
            expect(TranslateTweetWorker).to have_enqueued_sidekiq_job(post_id)
          end
        end

        context 'when the post has been imported before' do
          let!(:post) do
            Post.import(
              123,
              item_id: 'abc',
              feed_id: 234,
              content_text: 'Bar',
              title: 'An old title',
              url: 'https://example.com/123'
            )
          end

          it 'does not create a new post' do
            expect { response }.not_to(change { Post.count })
          end

          it 'updates the attributes of the existing post' do
            response
            expect(post.refresh).to have_attributes(
              content_text: 'Foo',
              title: '',
              url: 'https://example.com/abc'
            )
          end

          it 'does not update the created_at time' do
            expect { response }.not_to(change do
              post.refresh.created_at
            end)
          end

          it 'returns a description of the updated post' do
            expect(response.to_h).to match(
              id: post.id,
              item_id: 'abc',
              feed_id: 234,
              content_html: '',
              content_text: 'Foo',
              url: 'https://example.com/abc',
              title: '',
              published_at: '2018-07-20T19:14:38Z',
              modified_at: '2018-07-20T19:14:38Z',
              tweets: []
            )
          end
        end
      end
    end
  end

  describe '#cancel_tweet' do
    let(:post) do
      Post.import(123,
                  item_id: 'abc', feed_id: 1,
                  content_text: 'foo', url: 'foo')
    end
    let!(:tweet) { post.add_tweet(body: 'foo bar') }
    let(:request) { { id: tweet.id } }
    let(:response) { subject.call_rpc(:CancelTweet, request, env) }

    include_examples 'an unauthenticated request'
    include_examples 'a request from another user'

    context 'when an auth token is provided' do
      context 'and the tweet does not exist' do
        let(:request) { { id: tweet.id + 1 } }
        let(:env) { { token: other_token } }

        it 'returns a not found response' do
          expect(response).to be_a_twirp_error :not_found
        end
      end

      context "and the token matches the user id of the tweet's post" do
        let(:env) { { token: token } }

        it 'changes the tweet status to canceled' do
          response
          expect(tweet.refresh.status).to eq 'CANCELED'
        end

        it 'returns a description of the updated tweet' do
          expect(response).to eq Courier::PostTweet.new(
            id: tweet.id,
            post_id: post.id,
            body: 'foo bar',
            status: :CANCELED
          )
        end
      end
    end
  end

  describe '#update_tweet' do
    let(:post) do
      Post.import(123,
                  item_id: 'abc', feed_id: 1,
                  content_text: 'foo', url: 'foo')
    end
    let!(:tweet) { post.add_tweet(body: 'foo bar') }
    let(:request) { { id: tweet.id, body: 'bar foo' } }
    let(:response) { subject.call_rpc(:UpdateTweet, request, env) }

    include_examples 'an unauthenticated request'
    include_examples 'a request from another user'

    context 'when an auth token is provided' do
      context 'and the tweet does not exist' do
        let(:request) { { id: tweet.id + 1 } }
        let(:env) { { token: other_token } }

        it 'returns a not found response' do
          expect(response).to be_a_twirp_error :not_found
        end
      end

      context "and the token matches the user id of the tweet's post" do
        let(:env) { { token: token } }

        it 'updates the body of the tweet' do
          response
          expect(tweet.refresh.body).to eq 'bar foo'
        end

        it 'returns a description of the updated tweet' do
          expect(response).to eq Courier::PostTweet.new(
            id: tweet.id,
            post_id: post.id,
            body: 'bar foo'
          )
        end

        it 'rejects the request if the tweet has been canceled' do
          tweet.update status: 'CANCELED'
          expect(response).to be_a_twirp_error :failed_precondition
        end

        it 'rejects the request if the tweet has already been posted' do
          tweet.update status: 'POSTED'
          expect(response).to be_a_twirp_error :failed_precondition
        end
      end
    end
  end
end
