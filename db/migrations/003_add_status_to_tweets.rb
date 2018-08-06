Sequel.migration do
  change do
    create_enum :tweet_status, %w[DRAFT CANCELED POSTED]
    alter_table :tweets do
      add_column :status, :tweet_status, null: false, default: 'DRAFT'
    end
  end
end
