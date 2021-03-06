namespace :moonshine do
  desc "Update config/moonshine.yml with a list of the required gems"
  task :gems => 'gems:base' do
    gem_array = Rails.configuration.gems.map do |gem|
      hash = { :name => gem.name }
      hash.merge!(:source => gem.source) if gem.source
      hash.merge!(:version => gem.requirement.to_s) if gem.requirement
      hash
    end
    
    # add our own gem requirements for every project...
    gem_array += (["aws-s3", "ruby-debug", "curb", "json", "mysql", "right_aws", "composite_primary_keys", "god", "RubyInline", "memcache-client", "SystemTimer", "haml"].map { |gem| { :name => gem } })
    
    if (RAILS_GEM_VERSION rescue false)
      gem_array << {:name => 'rails', :version => RAILS_GEM_VERSION }
    else
      gem_array << {:name => 'rails'}
    end
    config_path = File.join(Dir.pwd, 'config', 'gems.yml')
    File.open( config_path, 'w' ) do |out|
      YAML.dump(gem_array, out )
    end
    puts "config/gems.yml has been updated with your application's gem"
    puts "dependencies. Please commit these changes to your SCM or upload"
    puts "them to your server with the cap local_config:upload command."
  end
end
