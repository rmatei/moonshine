namespace :db do  
  desc "Backup the database to a file. Options: DIR=base_dir RAILS_ENV=production MAX=20" 
  task :backup => :environment do
    datestamp = Time.now.strftime("%Y-%m-%d_%H-%M-%S")    
    base_path = ENV["DIR"] || "db" 
    backup_base = File.join(base_path, 'backup')
    backup_folder = File.join(backup_base, datestamp)
    backup_file = File.join(backup_folder, "#{RAILS_ENV}_dump.sql.gz")    
    File.makedirs(backup_folder)    
    db_config = ActiveRecord::Base.configurations[RAILS_ENV]    
    
    host = db_config['host'] ? "-h #{db_config['host']} -P #{db_config['port']}" : ""
    sh "mysqldump #{host} -u #{db_config['username']} -p#{db_config['password']} -Q -O add-locks=FALSE -O lock-tables=FALSE #{db_config['database']} | gzip -c > #{backup_file}" 
    
    dir = Dir.new(backup_base)
    all_backups = dir.entries[2..-1].sort.reverse
    puts "Created backup: #{backup_file}"     
    # max_backups = 20 || ENV["MAX"].to_i
    # unwanted_backups = all_backups[max_backups..-1] || []
    # for unwanted_backup in unwanted_backups
    #   FileUtils.rm_rf(File.join(backup_base, unwanted_backup))
    #   puts "deleted #{unwanted_backup}" 
    # end
    # puts "Deleted #{unwanted_backups.length} backups, #{all_backups.length - unwanted_backups.length} backups available" 
  end
end
