# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::container-server' do
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

    it 'upgrades swift container packages' do
      expect(chef_run).to upgrade_package('swift-container')
    end

    it 'starts swift container services on boot' do
      node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = %w(host1 host2)
      %w(swift-container swift-container-auditor swift-container-replicator swift-container-updater swift-container-sync).each do |svc|
        expect(chef_run).to enable_service(svc)
      end
    end

    describe '/etc/swift/container-server.conf' do
      let(:file) { chef_run.template('/etc/swift/container-server.conf') }

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

      it 'has allowed sync hosts' do
        node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = %w(host1 host2)
        expect(chef_run).to render_file(file.name).with_content('allowed_sync_hosts = host1,host2')
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

    describe '/etc/swift/container-server.conf' do
      let(:file) { chef_run.template('/etc/swift/container-server.conf') }

      it 'creates account-server.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 00600
        )
      end

      describe 'default attribute values' do
        it_behaves_like 'a common swift server default attribute values checker', 'container', '0.0.0.0', '6001'

        it 'for allowed_sync_hosts' do
          expect(chef_run.node['openstack']['object-storage']['container-server']['allowed_sync_hosts']).to eq([])
        end
      end

      describe 'template contents' do
        it_behaves_like 'a common swift server configurator', 'container', '0.0.0.0', '6001'

        it_behaves_like 'some common swift server values'

        it 'sets allowed_sync_hosts when present' do
          node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = %w(host1 host2)
          expect(chef_run).to render_file(file.name).with_content(/^allowed_sync_hosts = host1,host2$/)
        end

        it 'does not set allowed_sync_hosts when not present' do
          node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = false
          expect(chef_run).not_to render_file(file.name).with_content(/^allowed_sync_hosts = $/)
        end

        context 'container-sync' do
          it 'sets sync_proxy when present' do
            node.set['openstack']['object-storage']['container-server']['container-sync']['sync_proxy'] = 'sync_proxy_value'
            expect(chef_run).to render_file(file.name).with_content(/^sync_proxy = sync_proxy_value$/)
          end

          it 'does not set allowed_sync_hosts when not present' do
            node.set['openstack']['object-storage']['container-server']['container-sync']['sync_proxy'] = false
            expect(chef_run).not_to render_file(file.name).with_content(/^sync_proxy = $/)
          end

          %w(log_name log_facility log_level interval container_time).each do |attr|
            it "sets the container-sync #{attr} attribute" do
              node.set['openstack']['object-storage']['container-server']['container-sync'][attr] = "#{attr}_value"
              expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
            end
          end
        end
      end
    end

    describe '/etc/swift/object-reconciler.conf' do
      let(:file) { chef_run.template('/etc/swift/container-reconciler.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates object-reconciler.conf' do
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

    describe '/etc/swift/container-sync-realms.conf' do
      before do
        node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = ['host1', 'host2', 'host3']
      end

      let(:file) { chef_run.template('/etc/swift/container-sync-realms.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates container-sync-realms.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 00600
        )
      end
    end
  end
end
