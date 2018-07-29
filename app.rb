require 'config/environment'

class PostsHandler
  include Courier::Authorization
end

class DocHandler
  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) unless doc_request?(env)
    [200, { 'Content-Type' => 'text/html' },
     [File.read(File.join(__dir__, 'doc', 'index.html'))]]
  end

  def doc_request?(env)
    env['REQUEST_METHOD'] == 'GET' && env['PATH_INFO'] =~ %r{^/?$}
  end
end

__END__
App = Courier::PostsService.new(PostsHandler.new)

App.before do |rack_env, env|
  env[:token] = rack_env['jwt.token']
end
