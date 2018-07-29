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

  class << self
    def import(user_id, attrs)
      insert_attrs, update_attrs = upsert_attributes user_id, attrs
      dataset
        .insert_conflict(constraint: :posts_pkey, update: update_attrs)
        .insert_select(insert_attrs)
    end

    private

    def upsert_attributes(user_id, attrs)
      time = dataset.current_datetime
      insert_attrs = attrs.dup.merge(
        user_id: user_id,
        created_at: time, # sidestepping model code, so we need to set
        updated_at: time  # these manually
      )
      non_update_attrs = %i[id feed_id user_id created_at]
      update_attrs = insert_attrs.reject { |k, _| non_update_attrs.include? k }
      [insert_attrs, update_attrs]
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
