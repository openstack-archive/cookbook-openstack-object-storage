# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::container-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] =  ['host1', 'host2', 'host3']
      node.set['openstack']['object-storage']['disk_enum_expr'] = "[{ 'sda' => {}}]"
      node.set['openstack']['object-storage']['disk_test_filter'] = [
        'candidate =~ /sd[^a]/ or candidate =~ /hd[^a]/ or candidate =~ /vd[^a]/ or candidate =~ /xvd[^a]/',
        "File.exist?('/dev/' + candidate)",
        "not system('/sbin/parted /dev/' + candidate + ' -s print | grep linux-swap')",
        "not info.has_key?('removable') or info['removable'] == 0.to_s"]
      # mock out an interface on the storage node
      node.set['network'] = MOCK_NODE_NETWORK_DATA['network']
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'

    it 'upgrades swift container packages' do
      expect(chef_run).to upgrade_package('swift-container')
    end

    it 'starts swift container services on boot' do
      %w{swift-container swift-container-auditor swift-container-replicator swift-container-updater swift-container-sync}.each do |svc|
        expect(chef_run).to enable_service(svc)
      end
    end

    describe '/etc/swift/container-server.conf' do
      let(:file) { chef_run.template('/etc/swift/container-server.conf') }

      it 'creates account-server.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0600
        )
      end

      it 'has allowed sync hosts' do
        expect(chef_run).to render_file(file.name).with_content('allowed_sync_hosts = host1,host2,host3')
      end

      { 'bind_ip' => '0.0.0.0',
        'bind_port' => '6001',
        'log_statsd_default_sample_rate' => '1',
        'log_statsd_metric_prefix' => 'openstack.swift.Fauxhai' }.each do |k, v|
        it "sets the #{k}" do
          expect(chef_run).to render_file(file.name).with_content(/^#{Regexp.quote("#{k} = #{v}")}$/)
        end
      end
    end

    describe 'container sync' do
      let(:file) { chef_run.cookbook_file('/etc/init/swift-container-sync.conf') }
      let(:link) { chef_run.link('/etc/init.d/swift-container-sync') }

      it 'creates /etc/init/swift-container-sync.conf' do
        expect(chef_run).to create_cookbook_file(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0755
        )
      end

      it 'creates /etc/init.d/swift-container-sync' do
        expect(chef_run).to create_link(link.name)
      end
    end

    describe '/etc/swift/container-server.conf' do
      let(:file) { chef_run.template('/etc/swift/container-server.conf') }

      before do
        node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = []
      end

      it 'has no allowed_sync_hosts on empty lists' do
        expect(chef_run).not_to render_file(file.name).with_content(/^allowed_sync_hots =/)
      end
    end
  end
end
