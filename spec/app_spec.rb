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
end
