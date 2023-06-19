namespace :db do
  namespace :migrations do
    desc 'Clear schema_migrations table'
    # to be used after a bundle exec rails db:schema:load when specific migration alignment is required
    task setup: :environment do
      puts "seetting schema_migration table from migrations list in #{Rails.root}/lib/tasks"
      ActiveRecord::Base.connection.exec_query('delete from schema_migrations')
      File.readlines("#{Rails.root}/lib/tasks/migrations_list.txt").each do |line|
        ActiveRecord::Base.connection.exec_query("insert into schema_migrations (version) values (#{line})")
      end
    end
  end
end
