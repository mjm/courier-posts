Sequel.migration do
  change do
    # note to self: composite primary keys are a mistake
    alter_table :posts do
      drop_constraint :posts_pkey
      rename_column :id, :item_id
      add_primary_key :id
      add_unique_constraint %i[item_id feed_id user_id], name: :unique_posts
    end

    create_table :tweets do
      primary_key :id
      foreign_key :post_id, :posts, on_delete: :restrict
      String :body, text: true, null: false
    end
  end
end
