require 'config/environment'

class PostsHandler
  include Courier::Authorization

  def get_user_posts(req, env)
    require_user env, id: req.user_id do
      posts = Post.by_user(req.user_id).recent.all
      { posts: posts.map(&:to_proto) }
    end
  end

  def get_post(req, env)
    require_token env do
      post = Post[id: req.id, user_id: env[:token].user_id]
      return Twirp::Error.not_found 'No post found' unless post

      post.to_proto
    end
  end

  def import_post(req, env)
    require_user env, id: req.user_id, allow_service: true do
      post = Post.import(req.user_id, req.post.to_h)
      post.to_proto
    end
  end
end

App = Courier::PostsService.new(PostsHandler.new)

App.before do |rack_env, env|
  env[:token] = rack_env['jwt.token']
end
