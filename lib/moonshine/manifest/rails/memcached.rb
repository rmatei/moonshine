module Moonshine::Manifest::Rails::Memcached
  
  def memcached
    package 'memcached', :ensure => :installed 
    service 'memcached', :ensure => :running, :enable => true, :require => package('memcached')
  end

end