module Moonshine::Manifest::Rails::Os
  # Set up cron and enable the service. You can create cron jobs in your
  # manifests like so:
  #
  #   cron :run_me_at_three
  #     :command => "/usr/sbin/something",
  #     :user => root,
  #     :hour => 3
  #
  #   cron 'rake:task',
  #       :command => "cd #{rails_root} && RAILS_ENV=#{ENV['RAILS_ENV']} rake rake:task",
  #       :user => configuration[:user],
  #       :minute => 15
  def cron_packages
    service "cron", :require => package("cron"), :ensure => :running
    package "cron", :ensure => :installed
    
    if configuration[:cron_switch] and configuration[:cron_switch] == true
      package "logrotate", :ensure => :installed, :require => package("cron"), :notify => service("cron")
      
      safename = "#{configuration[:deploy_to]}/shared/log/*.log".gsub(/[^a-zA-Z]/, '')
    
      cron :rotate_railslog, 
        :command => "/usr/sbin/logrotate -f /etc/logrotate.d/#{safename}.conf",
        :user => 'root',
        :minute => 15,
        :require => package("cron")
    end
  end
  
  # Server monitoring
  def munin
    package "munin-node", :ensure => :installed
    package "munin", :ensure => :installed
    service "munin-node", :require => package("munin-node"), :ensure => :running
    
    file "/etc/apache2/sites-enabled/munin",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'munin.vhost.erb')),
      :notify => service("apache2")
  end

  # Create a MOTD to remind those logging in via SSH that things are managed
  # with Moonshine
  def motd
    motd_contents ="""-----------------
Moonshine Managed
-----------------

  Application:  #{configuration[:application]}
  Repository:   #{configuration[:repository]}
  Deploy Path:  #{configuration[:deploy_to]}

----------------
  A Reminder
----------------
As the configuration of this server is managed with Moonshine, please refrain
from installing any gems, packages, or dependencies directly on the server.
----------------
"""
    file '/var/run/motd',
      :mode => '644',
      :content => `uname -snrvm`+motd_contents
    file '/etc/motd.tail',
      :mode => '644',
      :content => motd_contents
  end

  # Install postfix.
  def postfix
    package 'postfix', :ensure => :latest
  end

  # Install ntp and enables the ntp service.
  def ntp
    package 'ntp', :ensure => :latest
    service 'ntp', :ensure => :running, :require => package('ntp'), :pattern => 'ntpd'
  end

  # Set the system timezone to <tt>configuration[:time_zone]</tt> or 'UTC' by
  # default.
  def time_zone
    zone = configuration[:time_zone] || 'UTC'
    zone = 'UTC' if zone.nil? || zone.strip == ''
    file "/etc/timezone",
      :content => zone+"\n",
      :ensure => :present
    file "/etc/localtime",
      :ensure => "/usr/share/zoneinfo/#{zone}",
      :notify => service('ntp')
  end
  
  def psmisc
    package 'psmisc', :ensure => :latest
  end
  
  def libxml_dev
    package 'libxml2-dev', :ensure => :latest
  end
  
  def curl
    package 'curl', :ensure => :latest
  end

private

  #Provides a helper for creating logrotate config for various parts of your
  #stack. For example:
  #
  #  logrotate('/srv/theapp/shared/logs/*.log', {
  #    :options => %w(daily missingok compress delaycompress sharedscripts),
  #    :postrotate => 'touch /srv/theapp/current/tmp/restart.txt'
  #  })
  #
  def logrotate(log_or_glob, options = {}, name = nil)
    options = options.respond_to?(:to_hash) ? options.to_hash : {}

    package "logrotate", :ensure => :installed, :require => package("cron"), :notify => service("cron")

    safename = name || log_or_glob.gsub(/[^a-zA-Z]/, '')

    file "/etc/logrotate.d/#{safename}.conf",
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), "templates", "logrotate.conf.erb"), binding),
      :notify => service("cron"),
      :alias => "logrotate_#{safename}"
  end

end
