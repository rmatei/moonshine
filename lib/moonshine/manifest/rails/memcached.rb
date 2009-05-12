module Moonshine::Manifest::Rails::Memcached
  
  def memcached
    package 'memcached', :ensure => :installed 
    service 'memcached', :ensure => :running, :enable => true, :require => package('memcached')
    
    file '/etc/memcached.conf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'memcached.conf.erb')),
      :notify => service("memcached")
  end
  

end