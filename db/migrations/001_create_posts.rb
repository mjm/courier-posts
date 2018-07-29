Sequel.migration do
  change do
    create_table :posts do
      String :id, null: false
      Integer :feed_id, null: false
      Integer :user_id, null: false
      primary_key %i[id feed_id user_id]

      String :content_html, text: true, null: false, default: ''
      String :content_text, text: true, null: false, default: ''
      String :title, null: false, default: ''
      String :url, null: false

      DateTime :created_at, null: false
      DateTime :updated_at, null: false
    end
  end
end
