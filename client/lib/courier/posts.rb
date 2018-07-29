require 'courier/posts/version'
require 'courier/posts/service_twirp'

class Courier::PostsClient
  class << self
    def connect(**options)
      new(create_connection(**options))
    end

    private

    def create_connection(url: ENV['COURIER_POSTS_URL'],
                          token: nil,
                          logger: false)
      Faraday.new(url) do |conn|
        conn.request :authorization, 'Bearer', token if token
        conn.response :logger if logger
        conn.adapter :typhoeus
      end
    end
  end
end
