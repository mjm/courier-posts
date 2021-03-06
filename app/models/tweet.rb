class Tweet < Sequel::Model(DB[:tweets])
  many_to_one :post

  def draft?
    status == 'DRAFT'
  end

  def to_proto
    Courier::PostTweet.new(
      id: id,
      post_id: post_id,
      body: body,
      status: status,
      user_id: post.user_id,
      posted_at: posted_at ? posted_at.getutc.iso8601 : '',
      posted_tweet_id: posted_tweet_id || ''
    )
  end
end
