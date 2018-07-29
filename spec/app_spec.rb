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
            Post.create(user_id: 123, id: '123', feed_id: 1, content_text: 'Foo', url: 'https://example.com/123')
            Post.create(user_id: 123, id: '234', feed_id: 1, content_html: '<p>Foo</p>', url: 'https://example.com/234')
            Post.create(user_id: 234, id: '234', feed_id: 1, content_text: 'Foo', url: 'https://example.com/234')
          end

          it 'returns a list of the posts for the user in the reverse order of when they were added' do
            expect(posts.map(&:to_h)).to match [
              {
                id: '234',
                feed_id: 1,
                content_html: '<p>Foo</p>',
                content_text: '',
                url: 'https://example.com/234',
                title: ''
              },
              {
                id: '123',
                feed_id: 1,
                content_html: '',
                content_text: 'Foo',
                url: 'https://example.com/123',
                title: ''
              }
            ]
          end
        end
      end
    end
  end

  describe '#import_post' do
    let(:request) do
      {
        user_id: 123,
        post: Courier::Post.new(
          id: 'abc',
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
              id: 'abc',
              feed_id: 234,
              content_html: '',
              content_text: 'Foo',
              url: 'https://example.com/abc',
              title: ''
            )
          end
        end

        context 'when the post has been imported before' do
          before do
            Post.import(
              123,
              id: 'abc',
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
            post = Post[id: 'abc', feed_id: 234, user_id: 123]
            expect(post).to have_attributes(
              content_text: 'Foo',
              title: '',
              url: 'https://example.com/abc'
            )
          end

          it 'does not update the created_at time' do
            expect { response }.not_to(change do
              Post[id: 'abc', feed_id: 234, user_id: 123].created_at
            end)
          end

          it 'returns a description of the updated post' do
            expect(response.to_h).to match(
              id: 'abc',
              feed_id: 234,
              content_html: '',
              content_text: 'Foo',
              url: 'https://example.com/abc',
              title: ''
            )
          end
        end
      end
    end
  end
end
