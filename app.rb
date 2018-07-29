require 'config/environment'

class PostsHandler
  include Courier::Authorization

  def get_user_posts(req, env)
    require_user env, id: req.user_id do
      posts = Post.by_user(req.user_id).recent.all
      { posts: posts.map(&:to_proto) }
    end
  end

  def import_post(req, env)
    require_user env, id: req.user_id do
      post = Post.import(req.user_id, req.post.to_h)
      post.to_proto
    end
  end
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

App = Courier::PostsService.new(PostsHandler.new)

App.before do |rack_env, env|
  env[:token] = rack_env['jwt.token']
end
