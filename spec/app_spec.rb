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

        context 'when there are no posts' do
          it 'returns an empty list of posts' do
            expect(response.to_hash).to match(posts: [])
          end
        end

        context 'when there are some posts' do
          it 'returns a list of the posts in the reverse order of when they were added'
        end
      end
    end
  end
end
