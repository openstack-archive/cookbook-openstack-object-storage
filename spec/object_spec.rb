# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::object-server' do
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

    it 'upgrades swift packages' do
      expect(chef_run).to upgrade_package('swift-object')
    end

    it 'starts swift object services on boot' do
      %w(swift-object swift-object-replicator swift-object-auditor swift-object-updater).each do |svc|
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

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates object-server.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 00600
        )
      end

      describe 'default attribute values' do
        it_behaves_like 'a common swift server default attribute values checker', 'object', '0.0.0.0', '6000'
      end

      it_behaves_like 'a common swift server configurator', 'object', '0.0.0.0', '6000'

      it_behaves_like 'some common swift server values'

      describe 'default replicator values' do
        { 'run_pause' => '30',
          'reclaim_age' => '604800' }.each do |k, v|
          it "sets the default for #{k}" do
            expect(chef_run).to render_config_file(file.name).with_section_content('object-replicator', /^#{Regexp.quote("#{k} = #{v}")}$/)
          end
        end
      end
    end

    describe '/etc/swift/object-expirer.conf' do
      let(:file) { chef_run.template('/etc/swift/object-expirer.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates object-expirerr.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 00600
        )
      end

      it 'sets the memcache_servers attribute' do
        expect(chef_run).to render_file(file.name).with_content(/^memcache_servers = host1:111,host2:222$/)
      end
    end
  end
end
