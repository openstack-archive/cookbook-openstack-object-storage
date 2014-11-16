# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::object-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
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

    it 'upgrades swift packages' do
      expect(chef_run).to upgrade_package('swift-object')
    end

    it 'starts swift object services on boot' do
      %w{swift-object swift-object-replicator swift-object-auditor swift-object-updater}.each do |svc|
        expect(chef_run).to enable_service(svc)
      end
    end

    describe '/var/spool/crontab/root' do
      it 'template contents' do
        skip 'TODO: check for recon script'
      end
    end

    describe '/etc/swift/object-server.conf' do
      let(:file) { chef_run.template('/etc/swift/object-server.conf') }

      it 'creates object-server.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0600
        )
      end

      describe 'default attribute values' do
        it_behaves_like 'a common swift server default attribute values checker', 'object'

        it 'uses default attribute value for bind_port' do
          expect(chef_run.node['openstack']['object-storage']['network']['object-bind-port']).to eq('6000')
        end
      end

      it_behaves_like 'a common swift server configurator', 'object'
    end
  end
end
