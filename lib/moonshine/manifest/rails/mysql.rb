module Moonshine::Manifest::Rails::Mysql

  # Installs <tt>mysql-server</tt> from apt and enables the <tt>mysql</tt>
  # service. Also creates a configuration file at
  # <tt>/etc/mysql/conf.d/moonshine.cnf</tt>. See
  # <tt>templates/moonshine.cnf</tt> for configuration options.
  def mysql_server
    package 'mysql-server', :ensure => :installed
    service 'mysql', :ensure => :running, :require => [
      package('mysql-server'),
      package('mysql')
    ]
    #ensure the mysql key is present on the configuration hash
    configure(:mysql => {})
    file '/etc/mysql', :ensure => :directory
    file '/etc/mysql/conf.d', :ensure => :directory
    file '/etc/mysql/conf.d/innodb.cnf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'innodb.cnf.erb')),
      :before => package('mysql-server')
    file '/etc/mysql/conf.d/moonshine.cnf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'moonshine.cnf.erb')),
      :require => package('mysql-server'),
      :notify => service('mysql')
    file '/etc/logrotate.d/varlogmysql.conf', :ensure => :absent
  end

  # Install the <tt>mysql</tt> rubygem and dependencies
  def mysql_gem
    gem('mysql')
  end

  # GRANT the database user specified in the current <tt>database_environment</tt>
  # permisson to access the database with the supplied password
  def mysql_user
    grant_queries = allowed_hosts.map { |host| grant_query(host) }

    exec "mysql_user",
      :command => mysql_query(grant_queries.join),
      :unless => mysql_query("show grants for #{database_environment[:username]}@#{allowed_hosts.last};"),
      :require => exec('mysql_database'),
      :before => exec('rake tasks'),
      :notify => exec('db_bootstrap')
  end

  # Create the database from the current <tt>database_environment</tt>
  def mysql_database
    exec "mysql_database",
      :command => mysql_query("create database #{database_environment[:database]};"),
      :unless => mysql_query("show create database #{database_environment[:database]};"),
      :require => service('mysql')
  end

  # Noop <tt>/etc/mysql/debian-start</tt>, which does some nasty table scans on
  # MySQL start.
  def mysql_fixup_debian_start
    file '/etc/mysql/debian-start',
      :ensure => :present,
      :content => "#!/bin/bash\nexit 0",
      :mode => '755',
      :owner => 'root',
      :require => package('mysql-server')
  end

private

  # Internal helper to shell out and run a query. Doesn't select a database.
  def mysql_query(sql)
    "/usr/bin/mysql -u root -p -e \"#{sql}\""
  end
  
  # The hosts that will be granted DB access.
  # Returns localhost + whatever hosts are specified in configuration.
  def allowed_hosts
    if remote_database?
      configuration[:servers][:app] | ["localhost"] # always allow localhost
    else
      ["localhost"]
    end
  end
  
  # The SQL query that grants DB access to a certain IP.
  def grant_query(host = "localhost")
    "GRANT ALL PRIVILEGES 
    ON #{database_environment[:database]}.*
    TO #{database_environment[:username]}@#{host}
    IDENTIFIED BY '#{database_environment[:password]}';
    FLUSH PRIVILEGES;"
  end

end