require 'time'

class Post < Sequel::Model(DB[:posts])
  plugin :timestamps, update_on_create: true

  one_to_many :tweets

  dataset_module do
    def by_user(user_id)
      where(user_id: user_id)
    end

    eager :with_tweets, :tweets
    order :most_recent_first, Sequel.desc(:published_at)
    limit :top_twenty, 20

    def recent
      most_recent_first
        .with_tweets
        .top_twenty
    end
  end

  class << self
    def import(user_id, attrs)
      attrs = attrs.dup
      autopost_delay = attrs.delete(:autopost_delay) || 0
      insert_attrs, update_attrs = upsert_attributes user_id, attrs
      result = dataset.returning
                      .insert_conflict(constraint: :unique_posts,
                                       update: update_attrs)
                      .insert_select(insert_attrs)
      TranslateTweetWorker.perform_async(result.id, autopost_delay)
      result
    end

    private

    def upsert_attributes(user_id, attrs)
      insert_attrs = insert_attributes user_id, attrs
      non_update_attrs = %i[item_id feed_id user_id created_at]
      update_attrs = insert_attrs.reject { |k, _| non_update_attrs.include? k }
      [insert_attrs, update_attrs]
    end

    def insert_attributes(user_id, attrs)
      time = dataset.current_datetime
      insert_attrs = attrs.dup
      insert_attrs.delete(:id)
      insert_attrs.delete(:tweets)
      insert_attrs.merge!(
        user_id: user_id,
        created_at: time, # sidestepping model code, so we need to set
        updated_at: time  # these manually
      )
      %i[published_at modified_at].each do |field|
        if insert_attrs.key?(field) && insert_attrs[field].is_a?(String)
          insert_attrs[field] = Time.iso8601(insert_attrs[field])
        end
      end
      insert_attrs
    end
  end

  def to_proto
    Courier::Post.new(
      id: id,
      item_id: item_id,
      feed_id: feed_id,
      content_html: content_html,
      content_text: content_text,
      url: url,
      title: title,
      published_at: published_at.getutc.iso8601,
      modified_at: modified_at.getutc.iso8601,
      tweets: tweets.map(&:to_proto)
    )
  end
end
