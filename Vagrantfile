#require 'berkshelf/vagrant'

default_box_image = "precise64"
default_box_url = "http://files.vagrantup.com/precise64.box"

ENV['CHEF_ENVIRONMENT'] ||= 'development'

def parse_json(path)
  JSON.parse(File.open(path) { |f| f.read }, :create_additions => false)
end

core = {
  :chefserver => {
    :url => default_box_url,
    :box => default_box_image,
    :ip => "10.0.0.2",
  },
}

storage_boxes = {
  :storage1 => {
    :url => default_box_url,
    :box => default_box_image,
    :ip => "10.0.0.10",
  },
  :storage2 => {
    :url => default_box_url,
    :box => default_box_image,
    :ip => "10.0.0.11",
  },
  :storage3 => {
    :url => default_box_url,
    :box => default_box_image,
    :ip => "10.0.0.12",
  },
}

Vagrant::Config.run do |config|

  core.each_pair do |name, options|

    config.vm.define name do |box|

      # Some metadata
      box.vm.box = options[:box]
      box.vm.host_name = name.to_s
      box.vm.box_url = options[:url]

      # Use this when debugging
      # box.vm.boot_mode = :gui

      # Hardware configuration
      box.vm.customize ["modifyvm", :id, "--memory", 512]
      box.vm.customize ["modifyvm", :id, "--cpus", 1]
      box.vm.customize ["modifyvm", :id, "--name", name]

      # Networking, in addition to the bridged interface
      box.vm.network :hostonly, options[:ip]

      box.vm.provision :chef_solo do |chef|
        chef.log_level = :debug
        chef.recipe_url = "http://s3.amazonaws.com/chef-solo/bootstrap-latest.tar.gz"
        chef.run_list.clear
        chef.json = {
          :chef_server=> {
            :url=> "http://#{options[:ip]}:4000",
            :webui_enabled=> true,
          }
        }

        chef.add_recipe "apt"
        chef.add_recipe "build-essential"
        chef.add_recipe "chef-server::rubygems-install"

      end
    end
  end

  storage_boxes.each_pair do |name, options|

    config.vm.define name do |box|

      # Some metadata
      box.vm.box = options[:box]
      box.vm.host_name = name.to_s
      box.vm.box_url = options[:url]

      # Use this when debugging
      # box.vm.boot_mode = :gui

      # Hardware configuration
      box.vm.customize ["modifyvm", :id, "--memory", 512]
      box.vm.customize ["modifyvm", :id, "--cpus", 1]
      box.vm.customize ["modifyvm", :id, "--name", name]

      # Networking, in addition to the bridged interface
      box.vm.network :hostonly, options[:ip]

      # Provisioning
      box.vm.provision :chef_client do |chef|
        chef.chef_server_url = "http://#{core[:chefserver][:ip]}:4000/"
        chef.validation_key_path = "/tmp/swift-validation.pem"
        chef.environment = ENV['CHEF-ENVIRONMENT']
        chef.log_level = :debug
      end
    end

  end

end
