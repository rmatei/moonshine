set :branch, 'master'
set :scm, :git
set :git_enable_submodules, 1
ssh_options[:paranoid] = false
ssh_options[:forward_agent] = true
default_run_options[:pty] = true
set :keep_releases, 2

after 'deploy:restart', 'deploy:cleanup'
after 'deploy:symlink', 'app:symlinks:update'

#load the moonshine configuration into
require 'yaml'
begin
  hash = YAML.load_file(File.join((ENV['RAILS_ROOT'] || Dir.pwd), 'config', 'moonshine.yml'))
  hash.each do |key, value|
    set(key.to_sym, value)
  end
rescue Exception
  puts "To use Capistrano with Moonshine, please run 'ruby script/generate moonshine',"
  puts "edit config/moonshine.yml, then re-run capistrano."
  exit(1)
end

namespace :moonshine do

  desc <<-DESC
  Bootstrap a barebones Ubuntu system with Git, Ruby, RubyGems, and Moonshine
  dependencies. Called by deploy:setup.
  DESC
  task :bootstrap do
    begin
      config = YAML.load_file(File.join(Dir.pwd, 'config', 'moonshine.yml'))
      put(YAML.dump(config),"/tmp/moonshine.yml")
    rescue
      puts "Please run 'ruby script/generate moonshine' and configure config/moonshine.yml first"
      exit(0)
    end
    put(File.read(File.join(File.dirname(__FILE__), '..', 'lib', 'moonshine_setup_manifest.rb')),"/tmp/moonshine_setup_manifest.rb")
    put(File.read(File.join(File.dirname(__FILE__), "bootstrap.#{fetch(:ruby, 'ree')}.sh")),"/tmp/bootstrap.sh")
    sudo 'chmod a+x /tmp/bootstrap.sh'
    sudo '/tmp/bootstrap.sh'
    sudo 'rm /tmp/bootstrap.sh'
    sudo "shadow_puppet /tmp/moonshine_setup_manifest.rb"
    sudo 'rm /tmp/moonshine_setup_manifest.rb'
    sudo 'rm /tmp/moonshine.yml'
    
    # # add OurDelta sources - alternative MySQL builds
    # put(File.read(File.join(File.dirname(__FILE__), "bootstrap.ourdelta_mysql.sh")),"/tmp/bootstrap_ourdelta.sh")
    # sudo 'chmod a+x /tmp/bootstrap_ourdelta.sh'
    # sudo '/tmp/bootstrap_ourdelta.sh'
    # sudo 'rm /tmp/bootstrap_ourdelta.sh'
  end
  
  desc "Update REE to new version"
  task :update_ree do
    put(File.read(File.join(File.dirname(__FILE__), "ree_upgrade.sh")),"/tmp/ree_upgrade.sh")
    sudo 'chmod a+x /tmp/ree_upgrade.sh'
    sudo '/tmp/ree_upgrade.sh'
    sudo 'rm /tmp/ree_upgrade.sh'
  end

  desc "apt-get update"
  task :update_apt_get do
    sudo 'apt-get update'
  end

  desc 'Apply the Moonshine manifest for this application'
  task :apply do
    on_rollback do
      run "cd #{current_release} && RAILS_ENV=#{fetch(:rails_env, 'production')} rake --trace environment"
    end
    sudo "RAILS_ROOT=#{current_release} DEPLOY_STAGE=#{ENV['DEPLOY_STAGE']||fetch(:stage,'undefined')} RAILS_ENV=#{fetch(:rails_env, 'production')} shadow_puppet #{current_release}/app/manifests/#{fetch(:moonshine_manifest, 'application_manifest')}.rb"
  end

  desc "Update code and then run a console. Useful for debugging deployment."
  task :update_and_console do
    set :moonshine_apply, false
    deploy.update_code
    app.console
  end

  desc "Update code and then run 'rake environment'. Useful for debugging deployment."
  task :update_and_rake do
    set :moonshine_apply, false
    deploy.update_code
    run "cd #{current_release} && RAILS_ENV=#{fetch(:rails_env, 'production')} rake --trace environment"
  end

  after 'deploy:finalize_update' do
    local_config.upload
    local_config.symlink
  end

  before 'deploy:restart' do
    apply if fetch(:moonshine_apply, true) == true
  end

end

# just for messing around right now
# namespace :deploy do
#   task :default do
#     #puts roles.to_yaml
#     #puts find_servers.inspect
#   end
# end

namespace :app do

  namespace :symlinks do

    desc <<-DESC
    Link public directories to shared location.
    DESC
    task :update, :roles => [:app, :web] do
      fetch(:app_symlinks, []).each { |link| run "ln -nfs #{shared_path}/public/#{link} #{current_path}/public/#{link}" }
    end

  end

  desc "remotely console"
  task :console, :roles => :app, :except => {:no_symlink => true} do
    input = ''
    run "cd #{current_path} && ./script/console #{fetch(:rails_env, "production")}" do |channel, stream, data|
      next if data.chomp == input.chomp || data.chomp == ''
      print data
      channel.send_data(input = $stdin.gets) if data =~ /^(>|\?)>/
    end
  end

  desc "Show requests per second"
  task :rps, :roles => :app, :except => {:no_symlink => true} do
    count = 0
    last = Time.now
    run "tail -f #{shared_path}/log/#{fetch(:rails_env, "production")}.log" do |ch, stream, out|
      break if stream == :err
      count += 1 if out =~ /^Completed in/
      if Time.now - last >= 1
        puts "#{ch[:host]}: %2d Requests / Second" % count
        count = 0
        last = Time.now
      end
    end
  end

  desc "tail application log file"
  task :log, :roles => :app, :except => {:no_symlink => true} do
    run "tail -f #{shared_path}/log/#{fetch(:rails_env, "production")}.log" do |channel, stream, data|
      puts "#{data}"
      break if stream == :err
    end
  end

  desc "tail vmstat"
  task :vmstat, :roles => [:web, :db] do
    run "vmstat 5" do |channel, stream, data|
      puts "[#{channel[:host]}]"
      puts data.gsub(/\s+/, "\t")
      break if stream == :err
    end
  end

end

namespace :local_config do

  desc <<-DESC
  Uploads local configuration files to the application's shared directory for
  later symlinking (if necessary). Called if local_config is set.
  DESC
  task :upload do
    fetch(:local_config,[]).each do |file|
      filename = File.split(file).last
      if File.exist?( file )
        put(File.read( file ),"#{shared_path}/config/#{filename}")
      end
    end
  end
  
  desc <<-DESC
  Symlinks uploaded local configurations into the release directory.
  DESC
  task :symlink do
    fetch(:local_config,[]).each do |file|
      filename = File.split(file).last
      run "ls #{current_release}/#{file} 2> /dev/null || ln -nfs #{shared_path}/config/#{filename} #{current_release}/#{file}"
    end
  end
  
end

namespace :deploy do
  desc "Restart the Passenger processes on the app server by touching tmp/restart.txt."
  task :restart, :roles => :app, :except => { :no_release => true } do
    run "rm -f #{current_path}/tmp/stop.txt"
    run "sudo touch #{current_path}/tmp/restart.txt"
  end

  # [:start, :stop].each do |t|
  #   desc "#{t} task is a no-op with Passenger"
  #   task t, :roles => :app do ; end
  # end
  
  desc "Stop passenger and display public/503.html"
  task :stop, :roles => :app do
    run "sudo touch #{current_path}/tmp/stop.txt"
  end
  
  desc "Start passenger if it was stopped"
  task :start, :roles => :app do
    run "rm -f #{current_path}/tmp/stop.txt"
  end

  desc <<-DESC
    Prepares one or more servers for deployment. Before you can use any \
    of the Capistrano deployment tasks with your project, you will need to \
    make sure all of your servers have been prepared with `cap deploy:setup'. When \
    you add a new server to your cluster, you can easily run the setup task \
    on just that server by specifying the HOSTS environment variable:
 
      $ cap HOSTS=new.server.com deploy:setup
 
    It is safe to run this task on servers that have already been set up; it \
    will not destroy any deployed revisions or data.
  DESC
  task :setup, :except => { :no_release => true } do
    moonshine.bootstrap
  end
  
  # Migrations
  desc "Deploy code, run migrations, then restart app servers"
  task :migrations do
    default
    migrate
    restart
  end
  
  desc "Run DB migrations"
  task :migrate, :roles => :primary_app do
    run "cd #{current_path} && rake db:migrate RAILS_ENV=production"
  end
  
end


# Our additions...

after "deploy:update_code", "tag_last_deploy"
after "deploy:update_code", "newrelic:notice_deployment"
after "deploy:restart", "dj:restart"
#after "deploy", "deploy:restart"

namespace :status do
  desc "Tail production log file" 
  task :log, :roles => :app do
    run "tail -f #{shared_path}/log/production.log" do |channel, stream, data|
      puts "#{data}" 
      break if stream == :err    
    end
  end
  
  desc "Tail production log file, filtering warnings and errors" 
  task :errors, :roles => :app do
    run "tail -f #{shared_path}/log/production.log | grep '~~~'" do |channel, stream, data|
      puts "#{data}" 
      break if stream == :err    
    end
  end
  
  desc "Look at memory stats" 
  task :vmstat, :roles => :app do
    run "vmstat 10" do |channel, stream, data|
      puts "#{channel[:host]}: #{data}" 
      break if stream == :err    
    end
  end
  
  desc "Show all running processes" 
  task :processes, :roles => :app do
    run "ps aux"
  end
  
  desc "Look at number of Passenger instances"
  task :passenger, :roles => :app do
    sudo "passenger-status"
  end
  
  desc "Look at Passenger memory use"
  task :mem, :roles => :app do
    sudo "passenger-memory-stats"
  end
  
  desc "Get delayed job processes status through god"
  task :god, :roles => :app do
    sudo "god status dj"
  end
  
end

task :tag_last_deploy do
  desc "Tags deployment in git"
  set :timestamp, Time.now
  set :tag_name, "deployed_to_production_#{timestamp.strftime("%Y%m%d-%H%M")}"
  `git tag -a -m "Tagging deploy to production at #{timestamp.strftime("%Y%m%d-%H%M")}" #{tag_name} #{branch}`
  `git push --tags`
  puts "Tagged release with #{tag_name}."
end

desc "Reboot app servers"
task :reboot do
  sudo "reboot"
end

namespace :god do
  desc "Start god"
  task :start, :roles => :app do
    sudo "god -c /etc/god.conf || set $?=0"
  end
  
  desc "Kill god"
  task :stop, :roles => :app do
    sudo "god terminate || set $?=0"
  end
  
  desc "Reload god config"
  task :reload, :roles => :app do
    sudo "god load /etc/god.conf"
  end
end

namespace :dj do
  desc "Stop delayed job processes through god"
  task :stop, :roles => :app do
    # sudo "god stop dj"
    god.stop
    dj.killall
  end
  
  desc "Start delayed job processes through god"
  task :start, :roles  => :app do
    # sudo "god start dj"
    god.start
  end
  
  desc "Restart delayed job processes with new code and God config"
  task :restart, :roles => :app do
    dj.stop
    dj.start
  end
  
  task :killall, :roles => :app do
    run "sudo ps aux | grep 'rake jobs:work' | grep -v grep | awk '{print $2}' | xargs -n1 kill || set $?=0"
  end

  task :forcekill, :roles => :app do
    run "sudo ps aux | grep 'rake jobs:work' | grep -v grep | awk '{print $2}' | xargs -n1 kill -9 || set $?=0"
  end
end

namespace :cook_magic do
  desc "Load fixtures on production"
  task :seed_data, :roles => :app do
    run "cd #{current_path}; rake db:cook_magic:seed RAILS_ENV=production"
  end
end

def rake command, force_pass = false
  run "cd #{current_path}; rake #{command} RAILS_ENV=production #{force_pass ? " || set $?=0" : ""}"
end