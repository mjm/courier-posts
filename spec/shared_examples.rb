RSpec.shared_examples 'an unauthenticated request' do
  context 'when no auth token is provided' do
    let(:env) { {} }

    it 'returns an unauthenticated response' do
      expect(response).to be_a_twirp_error :unauthenticated
    end
  end
end

RSpec.shared_examples 'a request from another user' do
  context 'when an auth token from a different user is provided' do
    let(:env) { { token: other_token } }

    it 'returns a forbidden response' do
      expect(response).to be_a_twirp_error :permission_denied
    end
  end
end
