module Moonshine::Manifest::Rails::God
  
  def god    
    file '/etc/god.conf',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'god.conf.erb'))
    
    file '/etc/init.d/god',
      :ensure => :present,
      :content => template(File.join(File.dirname(__FILE__), 'templates', 'god.init.erb')),
      :mode => '755'
    
    exec ("start_on_boot"),
      :command => "/usr/sbin/update-rc.d -f god defaults"
      
  end
  
  def start_on_boot
    exec ("start_on_boot"), {
      :command => "/usr/sbin/update-rc.d -f god defaults"
    }
  end
  

end