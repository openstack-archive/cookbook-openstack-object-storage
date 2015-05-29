# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::account-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
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

    it 'upgrades swift account packages' do
      expect(chef_run).to upgrade_package('swift-account')
    end

    it 'upgrades swiftclient package' do
      expect(chef_run).to upgrade_package('python-swiftclient')
    end

    it 'starts swift account services on boot' do
      %w(swift-account swift-account-auditor swift-account-reaper swift-account-replicator).each do |svc|
        expect(chef_run).to enable_service(svc)
      end
    end

    describe '/etc/swift/account-server.conf' do
      let(:file) { chef_run.template('/etc/swift/account-server.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates account-server.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 00600
        )
      end

      describe 'default attribute values' do
        it_behaves_like 'a common swift server default attribute values checker', 'account', '0.0.0.0', '6002'
      end

      it_behaves_like 'a common swift server configurator', 'account', '0.0.0.0', '6002'

      it_behaves_like 'some common swift server values'
    end
  end
end
