RSpec.describe PostsHandler do
  subject { App }

  Token = Courier::Middleware::JWTToken
  let(:token) { Token.new('sub' => 'example', 'uid' => 123) }
  let(:other_token) { Token.new('sub' => 'example2', 'uid' => 124) }
  let(:env) { {} }

  describe '#get_user_posts' do
    let(:request) { { user_id: 123 } }
    let(:response) { subject.call_rpc(:GetUserPosts, request, env) }

    context 'when no auth token is provided' do
      it 'returns an unauthenticated response' do
        expect(response).to be_a_twirp_error :unauthenticated
      end
    end

    context 'when an auth token is provided' do
      context 'and the token does not match the user whose posts were requested' do
        let(:env) { { token: other_token } }

        it 'returns a forbidden response' do
          expect(response).to be_a_twirp_error :permission_denied
        end
      end

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
            Post.create(user_id: 123, item_id: '123', feed_id: 1, content_text: 'Foo', url: 'https://example.com/123')
            Post.create(user_id: 123, item_id: '234', feed_id: 1, content_html: '<p>Foo</p>', url: 'https://example.com/234')
            Post.create(user_id: 234, item_id: '234', feed_id: 1, content_text: 'Foo', url: 'https://example.com/234')
          end

          it 'returns a list of the posts for the user in the reverse order of when they were added' do
            expect(posts.map(&:to_h)).to match [
              {
                id: a_value > 0,
                item_id: '234',
                feed_id: 1,
                content_html: '<p>Foo</p>',
                content_text: '',
                url: 'https://example.com/234',
                title: '',
                tweets: []
              },
              {
                id: a_value > 0,
                item_id: '123',
                feed_id: 1,
                content_html: '',
                content_text: 'Foo',
                url: 'https://example.com/123',
                title: '',
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
        url: 'https://example.com/123'
      )
    end
    let(:request) { { id: post.id } }
    let(:response) { subject.call_rpc(:GetPost, request, env) }

    context 'when no auth token is provided' do
      it 'returns an unauthenticated error' do
        expect(response).to be_a_twirp_error :unauthenticated
      end
    end

    context 'when a token for a different user is provided' do
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
          url: 'https://example.com/123'
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
          url: 'https://example.com/abc'
        )
      }
    end
    let(:response) { subject.call_rpc(:ImportPost, request, env) }

    context 'when no auth token is provided' do
      it 'returns an unauthenticated response' do
        expect(response).to be_a_twirp_error :unauthenticated
      end
    end

    context 'when an auth token is provided' do
      context 'and the token does not match the user id in the request' do
        let(:env) { { token: other_token } }

        it 'returns a forbidden response' do
          expect(response).to be_a_twirp_error :permission_denied
        end
      end

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

    context 'when no auth token is provided' do
      it 'returns an unauthenticated response' do
        expect(response).to be_a_twirp_error :unauthenticated
      end
    end

    context 'when an auth token is provided' do
      context "and the token does not match the user id of the tweet's post" do
        let(:env) { { token: other_token } }

        it 'returns a forbidden response' do
          expect(response).to be_a_twirp_error :permission_denied
        end
      end

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
end
