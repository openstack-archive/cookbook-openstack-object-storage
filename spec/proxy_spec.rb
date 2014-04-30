# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::proxy-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
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

    it 'upgrades swauth package if swauth is selected' do
      expect(chef_run).to upgrade_package('swauth')
    end

    it 'starts swift-proxy on boot' do
      expect(chef_run).to enable_service('swift-proxy')
    end

    describe '/etc/swift/proxy-server.conf' do
      let(:file) { chef_run.template('/etc/swift/proxy-server.conf') }

      it 'creates proxy-server.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0600
        )
      end

      it 'has proper pipeline in template' do
        array = [
          /^pipeline = catch_errors healthcheck cache ratelimit swauth proxy-logging proxy-server$/,
          /^workers = 5$/
        ]
        array.each do |content|
          expect(chef_run).to render_file(file.name).with_content(content)
        end
      end

      context 'with domain_remap enabled' do
        before do
          node.set['openstack']['object-storage']['domain_remap']['enabled'] = true
        end

        it 'has proper pipeline in template' do
          array = [
            /^pipeline = catch_errors healthcheck cache ratelimit domain_remap swauth proxy-logging proxy-server$/,
            /^storage_domain = example.com$/,
            /^path_root = v1$/,
            /^reseller_prefixes = AUTH$/
          ]
          array.each do |content|
            expect(chef_run).to render_file(file.name).with_content(content)
          end
        end
      end

      context 'with formpost enabled' do
        before do
          node.set['openstack']['object-storage']['formpost']['enabled'] = true
        end

        it 'has proper pipeline in template' do
          array = [
            /^pipeline = catch_errors healthcheck cache ratelimit formpost swauth proxy-logging proxy-server$/
          ]
          array.each do |content|
            expect(chef_run).to render_file(file.name).with_content(content)
          end
        end
      end

      context 'with staticweb enabled' do
        before do
          node.set['openstack']['object-storage']['staticweb']['enabled'] = true
        end

        it 'has proper pipeline in template' do
          array = [
            /^pipeline = catch_errors healthcheck cache ratelimit swauth staticweb proxy-logging proxy-server$/,
            /^cache_timeout = 300$/
          ]
          array.each do |content|
            expect(chef_run).to render_file(file.name).with_content(content)
          end
        end
      end

      context 'with tempurl enabled' do
        before do
          node.set['openstack']['object-storage']['tempurl']['enabled'] = true
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
            expect(chef_run).to render_file(file.name).with_content(content)
          end
        end
      end
    end
  end
end
