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

  def cancel_tweet(req, env)
    require_token env do
      tweet = Tweet[req.id]
      return Twirp::Error.not_found 'No tweet found' unless tweet

      require_user env, id: tweet.post.user_id do
        tweet.update status: 'CANCELED'
        tweet.to_proto
      end
    end
  end

  def update_tweet(req, env)
    require_token env do
      tweet = Tweet[req.id]
      return Twirp::Error.not_found 'No tweet found' unless tweet

      require_user env, id: tweet.post.user_id do
        return Twirp::Error.failed_precondition 'Tweet is not a draft' unless tweet.draft?

        tweet.update body: req.body
        tweet.to_proto
      end
    end
  end

  def submit_tweet(req, env)
    require_token env do
      tweet = Tweet[req.id]
      return Twirp::Error.not_found 'No tweet found' unless tweet

      require_user env, id: tweet.post.user_id do
        PostTweetsWorker.perform_async([tweet.id])
        tweet.to_proto
      end
    end
  end
end

App = Courier::PostsService.new(PostsHandler.new)

App.before do |rack_env, env|
  env[:token] = rack_env['jwt.token']
end
