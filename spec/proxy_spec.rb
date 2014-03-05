# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::proxy-server' do
  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @node.set['cpu']['total'] = 6
      @chef_run.converge 'openstack-object-storage::proxy-server'
    end

    it 'installs memcache python packages' do
      expect(@chef_run).to install_package 'python-memcache'
    end

    it 'installs swift packages' do
      expect(@chef_run).to install_package 'swift-proxy'
    end

    it 'installs swauth package if swauth is selected' do
      expect(@chef_run).to install_package 'swauth'
    end

    it 'starts swift-proxy on boot' do
      expect(@chef_run).to enable_service('swift-proxy')
    end

    describe '/etc/swift/proxy-server.conf' do

      before do
        @file = @chef_run.template '/etc/swift/proxy-server.conf'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('swift')
        expect(@file.group).to eq('swift')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '600'
      end

      it 'has proper pipeline in template' do
        array = [
          /^pipeline = catch_errors healthcheck cache ratelimit swauth proxy-logging proxy-server$/,
          /^workers = 5$/
        ]
        array.each do |content|
          expect(@chef_run).to render_file(@file.name).with_content(content)
        end
      end
    end

    describe '/etc/swift/proxy-server.conf with domain_remap enabled' do

      before do
        @node = @chef_run.node
        @node.set['openstack']['object-storage']['domain_remap']['enabled'] = true
        @chef_run.converge 'openstack-object-storage::proxy-server'
        @file = @chef_run.template '/etc/swift/proxy-server.conf'
      end

      it 'has proper pipeline in template' do
        array = [
          /^pipeline = catch_errors healthcheck cache ratelimit domain_remap swauth proxy-logging proxy-server$/,
          /^storage_domain = example.com$/,
          /^path_root = v1$/,
          /^reseller_prefixes = AUTH$/
        ]
        array.each do |content|
          expect(@chef_run).to render_file(@file.name).with_content(content)
        end
      end
    end

    describe '/etc/swift/proxy-server.conf with formpost enabled' do

      before do
        @node = @chef_run.node
        @node.set['openstack']['object-storage']['formpost']['enabled'] = true
        @chef_run.converge 'openstack-object-storage::proxy-server'
        @file = @chef_run.template '/etc/swift/proxy-server.conf'
      end

      it 'has proper pipeline in template' do
        array = [
          /^pipeline = catch_errors healthcheck cache ratelimit formpost swauth proxy-logging proxy-server$/
        ]
        array.each do |content|
          expect(@chef_run).to render_file(@file.name).with_content(content)
        end
      end
    end

    describe '/etc/swift/proxy-server.conf with staticweb enabled' do

      before do
        @node = @chef_run.node
        @node.set['openstack']['object-storage']['staticweb']['enabled'] = true
        @chef_run.converge 'openstack-object-storage::proxy-server'
        @file = @chef_run.template '/etc/swift/proxy-server.conf'
      end

      it 'has proper pipeline in template' do
        array = [
          /^pipeline = catch_errors healthcheck cache ratelimit swauth staticweb proxy-logging proxy-server$/,
          /^cache_timeout = 300$/
        ]
        array.each do |content|
          expect(@chef_run).to render_file(@file.name).with_content(content)
        end
      end
    end

    describe '/etc/swift/proxy-server.conf with tempurl enabled' do

      before do
        @node = @chef_run.node
        @node.set['openstack']['object-storage']['tempurl']['enabled'] = true
        @chef_run.converge 'openstack-object-storage::proxy-server'
        @file = @chef_run.template '/etc/swift/proxy-server.conf'
      end

      it 'has proper pipeline in template' do
        array = [
          /^pipeline = catch_errors healthcheck cache ratelimit tempurl swauth proxy-logging proxy-server$/,
          /^incoming_remove_headers = x-timestamp$/,
          /^incoming_allow_headers = $/,
          'outgoing_remove_headers = x-object-meta-*',
          'outgoing_allow_headers = x-object-meta-public-*'
        ]
        array.each do |content|
          expect(@chef_run).to render_file(@file.name).with_content(content)
        end
      end
    end

  end
end
