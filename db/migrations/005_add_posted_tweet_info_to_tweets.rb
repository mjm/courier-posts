Sequel.migration do
  change do
    alter_table :tweets do
      add_column :posted_at, DateTime
      add_column :posted_tweet_id, String
    end
  end
end
