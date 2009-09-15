namespace :apache do
  desc "Reboot Apache" 
  task :restart, :roles => :app do
    sudo "sudo /etc/init.d/apache2 restart"
  end
end