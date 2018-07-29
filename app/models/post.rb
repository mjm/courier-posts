class Post < Sequel::Model(DB[:posts])
  unrestrict_primary_key
  plugin :timestamps, update_on_create: true

  dataset_module do
    def by_user(user_id)
      where(user_id: user_id)
    end

    def recent
      reverse(:created_at).limit(20)
    end
  end

  def to_proto
    Courier::Post.new(
      id: id,
      feed_id: feed_id,
      content_html: content_html,
      content_text: content_text,
      url: url,
      title: title
    )
  end
end
