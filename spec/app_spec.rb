RSpec.describe PostsHandler do
  subject { App }

  Token = Courier::Middleware::JWTToken
  let(:token) { Token.new('sub' => 'example', 'uid' => 123) }
  let(:other_token) { Token.new('sub' => 'example2', 'uid' => 124) }
  let(:env) { {} }
end
