namespace :memcached do
  desc "Reboot Memcached" 
  task :restart, :roles => :app do
    sudo "sudo /etc/init.d/memcached restart"
  end
end