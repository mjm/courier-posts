Sequel.migration do
  change do
    alter_table :posts do
      add_column :published_at, DateTime, null: false, default: Sequel.function(:NOW)
      add_column :modified_at, DateTime, null: false, default: Sequel.function(:NOW)
    end
  end
end
