# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::proxy-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      node.automatic['cpu']['total'] = 6

      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'
    include_examples 'keystone-authmode'

    it 'upgrades memcache python packages' do
      expect(chef_run).to upgrade_package('python-memcache')
    end

    it 'upgrades swift packages' do
      expect(chef_run).to upgrade_package('swift-proxy')
    end

    it 'does not upgrade swauth package' do
      expect(chef_run).not_to upgrade_package('swauth')
    end

    it 'starts swift-proxy on boot' do
      expect(chef_run).to enable_service('swift-proxy')
    end

    describe '/etc/swift/proxy-server.conf' do
      let(:file) { chef_run.template('/etc/swift/proxy-server.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates proxy-server.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 00600
        )
      end

      describe 'default attribute values' do
        it_behaves_like 'a common swift server default attribute values checker', 'proxy', nil, nil

        it 'has default contents' do
          array = [
            /^pipeline = catch_errors healthcheck cache ratelimit authtoken keystoneauth proxy-logging proxy-server$/,
            /^workers = auto$/
          ]
          array.each do |content|
            expect(chef_run).to render_file(file.name).with_content(content)
          end
        end

        it 'uses default attribute value for authmode' do
          expect(chef_run.node['openstack']['object-storage']['authmode']).to eq('keystone')
        end

        %w(tempurl formpost domain_remap staticweb).each do |attr|
          it "uses default attribute value for #{attr} enabled" do
            expect(chef_run.node['openstack']['object-storage'][attr]['enabled']).to eq(false)
          end
        end

        %w(swift_url swauth_url).each do |attr|
          it "uses default attribute value for #{attr}" do
            expect(chef_run.node['openstack']['object-storage'][attr]).to eq('http://127.0.0.1:8080/v1/')
          end
        end

        it 'uses default attribute value for container-server allowed_sync_hosts' do
          expect(chef_run.node['openstack']['object-storage']['container-server']['allowed_sync_hosts']).to eq([])
        end

        it 'uses default attribute value for domain_remap log_name' do
          expect(chef_run.node['openstack']['object-storage']['domain_remap']['log_name']).to eq('domain_remap')
        end

        it 'uses default attribute value for domain_remap log_facility' do
          expect(chef_run.node['openstack']['object-storage']['domain_remap']['log_facility']).to eq('LOG_LOCAL0')
        end

        it 'uses default attribute value for domain_remap log_level' do
          expect(chef_run.node['openstack']['object-storage']['domain_remap']['log_level']).to eq('INFO')
        end

        it 'uses default attribute value for domain_remap log_headers' do
          expect(chef_run.node['openstack']['object-storage']['domain_remap']['log_headers']).to eq('False')
        end

        it 'uses default attribute value for domain_remap storage_admin' do
          expect(chef_run.node['openstack']['object-storage']['domain_remap']['storage_domain']).to eq('example.com')
        end

        it 'uses default attribute value for domain_remap path_root' do
          expect(chef_run.node['openstack']['object-storage']['domain_remap']['path_root']).to eq('v1')
        end

        it 'uses default attribute value for domain_remap reseller_prefixes' do
          expect(chef_run.node['openstack']['object-storage']['domain_remap']['reseller_prefixes']).to eq('AUTH')
        end

        it 'uses default attribute value for staticweb cache_timeout' do
          expect(chef_run.node['openstack']['object-storage']['staticweb']['cache_timeout']).to eq(300)
        end

        it 'uses default attribute value for staticweb log_name' do
          expect(chef_run.node['openstack']['object-storage']['staticweb']['log_name']).to be_nil
        end

        it 'uses default attribute value for staticweb log_facility' do
          expect(chef_run.node['openstack']['object-storage']['staticweb']['log_facility']).to eq('LOG_LOCAL0')
        end

        it 'uses default attribute value for staticweb log_level' do
          expect(chef_run.node['openstack']['object-storage']['staticweb']['log_level']).to eq('INFO')
        end

        it 'uses default attribute value for staticweb access_log_name' do
          expect(chef_run.node['openstack']['object-storage']['staticweb']['access_log_name']).to eq('staticweb')
        end

        it 'uses default attribute value for staticweb access_log_facility' do
          expect(chef_run.node['openstack']['object-storage']['staticweb']['access_log_facility']).to eq('LOG_LOCAL0')
        end

        it 'uses default attribute value for staticweb access_log_level' do
          expect(chef_run.node['openstack']['object-storage']['staticweb']['access_log_level']).to eq('INFO')
        end

        it 'uses default attribute value for staticweb log_headers' do
          expect(chef_run.node['openstack']['object-storage']['staticweb']['log_headers']).to eq('False')
        end

        it 'uses default attribute value for tempurl incoming_remove_headers' do
          expect(chef_run.node['openstack']['object-storage']['tempurl']['incoming_remove_headers']).to eq('x-timestamp')
        end

        it 'uses default attribute value for tempurl incoming_allow_headers' do
          expect(chef_run.node['openstack']['object-storage']['tempurl']['incoming_allow_headers']).to eq('')
        end

        it 'uses default attribute value for tempurl outgoing_remove_headers' do
          expect(chef_run.node['openstack']['object-storage']['tempurl']['outgoing_remove_headers']).to eq('x-object-meta-*')
        end

        it 'uses default attribute value for tempurl outgoing_allow_headers' do
          expect(chef_run.node['openstack']['object-storage']['tempurl']['outgoing_allow_headers']).to eq('x-object-meta-public-*')
        end
      end

      describe 'template contents' do
        it_behaves_like 'a common swift server configurator', 'proxy', '127.0.0.1', '8080'

        context 'workers' do
          it 'sets the number of workers' do
            expect(chef_run).to render_file(file.name).with_content(/^workers = auto$/)
          end
        end

        context 'pipeline' do
          %w(domain_remap formpost staticweb).each do |pipeline_item|
            it "includes #{pipeline_item} in the pipeline when present" do
              node.set['openstack']['object-storage'][pipeline_item]['enabled'] = true
              expect(chef_run).to render_file(file.name).with_content(/^pipeline = .*#{pipeline_item}.*$/)
            end

            it "does not include #{pipeline_item} in the pipeline when not present" do
              node.set['openstack']['object-storage'][pipeline_item]['enabled'] = false
              expect(chef_run).not_to render_file(file.name).with_content(/^pipeline = .*#{pipeline_item}.*$/)
            end
          end

          it 'includes the tempurl element when it is enabled and authmode is swauth' do
            node.set['openstack']['object-storage']['authmode'] = 'swauth'
            node.set['openstack']['object-storage']['tempurl']['enabled'] = true
            expect(chef_run).to render_file(file.name).with_content(/^pipeline = .*tempurl.*$/)
          end

          it 'does not include the tempurl element when it is disabled' do
            node.set['openstack']['object-storage']['tempurl']['enabled'] = false
            expect(chef_run).not_to render_file(file.name).with_content(/^pipeline = .*tempurl.*$/)
          end

          it 'does not includes the tempurl element when authmode is not swauth' do
            node.set['openstack']['object-storage']['authmode'] = 'not_swauth'
            expect(chef_run).not_to render_file(file.name).with_content(/^pipeline = .*tempurl.*$/)
          end

          it 'includes keystone related items when authmode is keystone' do
            expect(chef_run).to render_file(file.name).with_content(/^pipeline = .*authtoken keystoneauth.*$/)
          end

          it 'does not include keystone related items when authmode is not keystone' do
            node.set['openstack']['object-storage']['authmode'] = 'not_keystone'
            expect(chef_run).not_to render_file(file.name).with_content(/^pipeline = .*authtoken keystoneauth.*$/)
          end

          it 'includes swauth item when authmode is swauth' do
            node.set['openstack']['object-storage']['authmode'] = 'swauth'
            expect(chef_run).to render_file(file.name).with_content(/^pipeline = .*swauth.*$/)
          end

          it 'does not include swauth item when authmode is not swauth' do
            node.set['openstack']['object-storage']['authmode'] = 'not_swauth'
            expect(chef_run).not_to render_file(file.name).with_content(/^pipeline = .*swauth.*$/)
          end
        end

        it 'sets account_autocreate when authmode is keystone' do
          expect(chef_run).to render_file(file.name).with_content(/^account_autocreate = true$/)
        end

        it 'does not set account_autocreate when authmode is not keystone' do
          node.set['openstack']['object-storage']['authmode'] = 'not_keystone'
          expect(chef_run).not_to render_file(file.name).with_content(/^account_autocreate = true$/)
        end

        context 'swauth enabled' do
          before do
            node.set['openstack']['object-storage']['authmode'] = 'swauth'
          end

          it 'has auth key override' do
            node.set['openstack']['object-storage']['authkey'] = '1234'
            expect(chef_run).to render_file(file.name).with_content(/^super_admin_key = 1234$/)
          end

          it 'sets allow_account_management attribute when authmode is swauth' do
            expect(chef_run).to render_file(file.name).with_content(/^allow_account_management = true$/)
          end

          it 'sets the default_swift_cluster attribute' do
            node.set['openstack']['object-storage']['swift_url'] = 'swift_url_value'
            node.set['openstack']['object-storage']['swauth_url'] = 'swauth_url_value'
            expect(chef_run).to render_file(file.name).with_content(/^default_swift_cluster = local#swift_url_value#swauth_url_value$/)
          end

          it 'sets allow_overrides when tempurl is enabled' do
            node.set['openstack']['object-storage']['tempurl']['enabled'] = true
            expect(chef_run).to render_file(file.name).with_content(/^allow_overrides = true$/)
          end

          it 'does not set allow_overrides when tempurl is disabled' do
            node.set['openstack']['object-storage']['tempurl']['enabled'] = false
            expect(chef_run).not_to render_file(file.name).with_content(/^allow_overrides = true$/)
          end

          it 'sets allowed_sync_hosts when present' do
            node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = %w(host1 host2)
            expect(chef_run).to render_file(file.name).with_content(/^allowed_sync_hosts = host1,host2$/)
          end

          it 'does not set allowed_sync_hosts when not present' do
            node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = nil
            expect(chef_run).not_to render_file(file.name).with_content(/^allowed_sync_hosts = $/)
          end
        end

        context 'swauth disabled' do
          before do
            node.set['openstack']['object-storage']['authmode'] = 'not_swauth'
          end

          it 'sets allow_account_management attribute when authmode is not swauth' do
            expect(chef_run).to render_file(file.name).with_content(/^allow_account_management = false$/)
          end

          it 'does not set the default_swift_cluster attribute' do
            expect(chef_run).not_to render_file(file.name).with_content(/^default_swift_cluster = local.*$/)
          end

          it 'does not set allow_overrides when tempurl is enabled' do
            node.set['openstack']['object-storage']['tempurl']['enabled'] = true
            expect(chef_run).not_to render_file(file.name).with_content(/^allow_overrides = true$/)
          end

          it 'does not set allowed_sync_hosts when present' do
            node.set['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = %w(host1 host2)
            expect(chef_run).not_to render_file(file.name).with_content(/^allowed_sync_hosts = host1,host2$/)
          end
        end

        context 'authtoken enabled' do
          { 'paste.filter_factory' => 'keystoneclient.middleware.auth_token:filter_factory',
            'auth_uri' => 'http://127.0.0.1:5000/v2.0',
            'identity_uri' => 'http://127.0.0.1:35357/',
            'auth_version' => 'v2.0',
            'admin_tenant_name' => 'service',
            'admin_user' => 'swift',
            'admin_password' => 'swift-pass',
            'signing_dir' => '/var/cache/swift/api'
          }.each do |k, v|
            it "sets the default for #{k}" do
              expect(chef_run).to render_config_file(file.name).with_section_content('filter:authtoken', /^#{Regexp.quote("#{k} = #{v}")}$/)
            end
          end
        end

        it 'sets the memcache_servers attribute' do
          expect(chef_run).to render_file(file.name).with_content(/^memcache_servers = host1:111,host2:222$/)
        end

        context 'domain_remap' do
          %w(log_name log_facility log_level log_headers).each do |attr|
            it "sets the #{attr} attribute" do
              node.set['openstack']['object-storage']['domain_remap'][attr] = "#{attr}_value"
              expect(chef_run).to render_file(file.name).with_content(/^set #{attr} = #{attr}_value$/)
            end
          end

          %w(storage_domain path_root reseller_prefixes).each do |attr|
            it "sets the #{attr} attribute" do
              node.set['openstack']['object-storage']['domain_remap'][attr] = "#{attr}_value"
              expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
            end
          end
        end

        context 'staticweb' do
          it 'sets the cache_timeout attribute' do
            node.set['openstack']['object-storage']['staticweb']['cache_timeout'] = 'cache_timeout_value'
            expect(chef_run).to render_file(file.name).with_content(/^cache_timeout = cache_timeout_value$/)
          end

          %w(log_name log_facility log_level access_log_name access_log_facility access_log_level log_headers).each do |attr|
            it "sets the #{attr} attribute" do
              node.set['openstack']['object-storage']['staticweb'][attr] = "#{attr}_value"
              expect(chef_run).to render_file(file.name).with_content(/^set #{attr} = #{attr}_value$/)
            end
          end
        end

        context 'tempurl' do
          %w(incoming_remove_headers incoming_allow_headers outgoing_remove_headers outgoing_allow_headers).each do |attr|
            it "sets the #{attr} attribute" do
              node.set['openstack']['object-storage']['tempurl'][attr] = "#{attr}_value"
              expect(chef_run).to render_file(file.name).with_content(/^#{attr} = #{attr}_value$/)
            end
          end
        end
      end
    end
  end
end
