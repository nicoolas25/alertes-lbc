unless DB.tables.include?(:requests)
  LOG.info 'Create table \'requests\'...'
  DB.create_table :requests do
    primary_key :id
    String :url
    String :page_id
    String :name
    Integer :period
    Time :last_verification

    index :url, :unique => true
  end
  LOG.info 'Table \'request\' have been successfully created!' if DB.tables.include?(:requests)
end


