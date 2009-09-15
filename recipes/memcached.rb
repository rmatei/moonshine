namespace :memcached do
  desc "Reboot Memcached" 
  task :restart, :roles => :app do
    sudo "sudo /etc/init.d/memcached restart"
  end

  desc "Show number of connections to Memcached"
  task :total_connections, :roles => :app do
    run "(sleep 1; echo stats; echo quit) | nc 127.0.0.1 11211 | grep total_connections"
  end
end