# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::container-server' do
  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] =  ['host1', 'host2', 'host3']
      @node.set['openstack']['object-storage']['disk_enum_expr'] = "[{ 'sda' => {}}]"
      @node.set['openstack']['object-storage']['disk_test_filter'] = [
        'candidate =~ /sd[^a]/ or candidate =~ /hd[^a]/ or candidate =~ /vd[^a]/ or candidate =~ /xvd[^a]/',
        "File.exist?('/dev/' + candidate)",
        "not system('/sbin/parted /dev/' + candidate + ' -s print | grep linux-swap')",
        "not info.has_key?('removable') or info['removable'] == 0.to_s"]

      # mock out an interface on the storage node
      @node.set['network'] = MOCK_NODE_NETWORK_DATA['network']

      @chef_run.converge 'openstack-object-storage::container-server'
    end

    it 'installs swift container packages' do
      expect(@chef_run).to install_package 'swift-container'
    end

    it 'starts swift container services on boot' do
      %w{swift-container swift-container-auditor swift-container-replicator swift-container-updater swift-container-sync}.each do |svc|
        expect(@chef_run).to enable_service(svc)
      end
    end

    describe '/etc/swift/container-server.conf' do

      before do
        @file = @chef_run.template '/etc/swift/container-server.conf'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('swift')
        expect(@file.group).to eq('swift')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '600'
      end

      it 'has allowed sync hosts' do
        expect(@chef_run).to render_file(@file.name).with_content('allowed_sync_hosts = host1,host2,host3')
      end

      { 'bind_ip' => '0.0.0.0',
        'bind_port' => '6001',
        'log_statsd_default_sample_rate' => '1',
        'log_statsd_metric_prefix' => 'openstack.swift.Fauxhai' }.each do |k, v|
        it "sets the #{k}" do
          expect(@chef_run).to render_file(@file.name).with_content(/^#{Regexp.quote("#{k} = #{v}")}$/)
        end
      end

    end

    it 'should create container sync upstart conf for ubuntu' do
      expect(@chef_run).to create_cookbook_file '/etc/init/swift-container-sync.conf'
    end

    it 'should create container sync init script for ubuntu' do
      expect(@chef_run).to create_link '/etc/init.d/swift-container-sync'
    end

    describe '/etc/swift/container-server.conf' do

      before do
        @node = @chef_run.node
        @node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = []
        @chef_run.converge 'openstack-object-storage::container-server'
        @file = @chef_run.template '/etc/swift/container-server.conf'
      end

      it 'has no allowed_sync_hosts on empty lists' do
        expect(@chef_run).not_to render_file(@file.name).with_content(/^allowed_sync_hots =/)
      end
    end
  end
end
