#The Rails Manifest includes recipes for Apache, Mysql, Sqlite3 and Rails
#running on Ubuntu 8.10 or greater.
class Moonshine::Manifest::Rails < Moonshine::Manifest
  def validate_platform
    unless Facter.lsbdistid == 'Ubuntu' && Facter.lsbdistrelease.to_f >= 8.1
      error = <<-ERROR


      Moonshine::Manifest::Rails is currently only supported on Ubuntu 8.10
      or greater. If you'd like to see your favorite distro supported, fork
      Moonshine on GitHub!
      ERROR
      raise NotImplementedError, error
    end
  end
  recipe :validate_platform

  configure(:apt_gems => YAML.load_file(File.join(File.dirname(__FILE__), 'rails', 'apt_gems.yml')))

  require File.join(File.dirname(__FILE__), 'rails', 'passenger.rb')
  include Moonshine::Manifest::Rails::Passenger
  require File.join(File.dirname(__FILE__), 'rails', 'mysql.rb')
  include Moonshine::Manifest::Rails::Mysql
  require File.join(File.dirname(__FILE__), 'rails', 'postgresql.rb')
  include Moonshine::Manifest::Rails::Postgresql
  require File.join(File.dirname(__FILE__), 'rails', 'sqlite3.rb')
  include Moonshine::Manifest::Rails::Sqlite3
  require File.join(File.dirname(__FILE__), 'rails', 'apache.rb')
  include Moonshine::Manifest::Rails::Apache
  require File.join(File.dirname(__FILE__), 'rails', 'rails.rb')
  include Moonshine::Manifest::Rails::Rails
  require File.join(File.dirname(__FILE__), 'rails', 'os.rb')
  include Moonshine::Manifest::Rails::Os
  require File.join(File.dirname(__FILE__), 'rails', 'memcached.rb')
  include Moonshine::Manifest::Rails::Memcached
  require File.join(File.dirname(__FILE__), 'rails', 'god.rb')
  include Moonshine::Manifest::Rails::God
  
  # A super recipe that uses the recipes for installing Apache, Passenger, 
  # MySQL, Rails, NTP, Cron, Postfix. To customize your stack, call the 
  # individual recipes you want to include rather than default_stack.
  def app_stack
    self.class.recipe :apache_server
    self.class.recipe :passenger_gem, :passenger_configure_gem_path, :passenger_apache_module, :passenger_site
    self.class.recipe :rails_logrotate, :libxml_dev, :curl
  end
  
  def db_stack
    self.class.recipe :mysql_config, :mysql_server, :mysql_gem, :mysql_database, :mysql_user, :mysql_fixup_debian_start, :db_bootstrap, :rails_migrations
  end
  
  # Basics that are used on all server roles
  def shared_stack
    self.class.recipe :rails_rake_environment, :rails_gems, :rails_directories
    self.class.recipe :ntp, :time_zone, :postfix, :cron_packages, :motd, :psmisc
  end

  # A super recipe for installing Apache, Passenger, a database, 
  # Rails, NTP, Cron, Postfix. To customize your stack, call the
  # individual recipes you want to include rather than default_stack.
  #
  # The database installed is based on the adapter in database.yml.
  def default_stack
    self.class.recipe :apache_server
    self.class.recipe :passenger_gem, :passenger_configure_gem_path, :passenger_apache_module, :passenger_site
    case database_environment[:adapter]
    when 'mysql'
      self.class.recipe :mysql_server, :mysql_gem, :mysql_database, :mysql_user, :mysql_fixup_debian_start
    when 'postgresql'
      self.class.recipe :postgresql_server, :postgresql_gem, :postgresql_user, :postgresql_database
    when 'sqlite' || 'sqlite3'
      self.class.recipe :sqlite3
    end
    self.class.recipe :rails_rake_environment, :rails_gems, :rails_directories, :rails_bootstrap, :rails_migrations, :rails_logrotate
  end
  
end