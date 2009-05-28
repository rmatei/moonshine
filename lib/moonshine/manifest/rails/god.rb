module Moonshine::Manifest::Rails::God
  
  def god    
    file '/etc/god.conf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'god.conf.erb'))
    
    file '/etc/init.d/god.conf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'god.conf.erb'))
  end
  

end