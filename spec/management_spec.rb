# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::management-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'

    it 'upgrades swift swauth package' do
      expect(chef_run).to upgrade_package 'swauth'
    end

    describe '/etc/swift/dispersion.conf' do
      let(:file) { chef_run.template('/etc/swift/dispersion.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates dispersion.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0600
        )
      end

      it 'template default contents' do
        [
          %r{^auth_url = http://127.0.0.1:8080/auth/v1.0$},
          /^auth_user = dispersion_auth_user-secret$/,
          /^auth_key = dispersion_auth_key-secret$/
        ].each do |content|
          expect(chef_run).to render_file(file.name).with_content(content)
        end
      end

      it 'has template overrides' do
        node.set['openstack']['object-storage']['auth_url'] = 'url'
        node.set['openstack']['object-storage']['dispersion']['auth_user'] = 'user'
        node.set['openstack']['object-storage']['dispersion']['auth_key'] = 'key'
        [
          /^auth_url = url$/,
          /^auth_user = user$/,
          /^auth_key = key$/
        ].each do |content|
          expect(chef_run).to render_file(file.name).with_content(content)
        end
      end
    end

    describe '/usr/local/bin/swift-statsd-publish.py' do
      let(:file) { chef_run.template('/usr/local/bin/swift-statsd-publish.py') }

      it 'creates /usr/local/bin/swift-statsd-publish.py' do
        expect(chef_run).to create_template(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0755
        )
      end

      it 'has expected statsd host' do
        expect(chef_run).to render_file(file.name).with_content(
          "self.statsd_host              = '127.0.0.1'"
        )
      end
    end
  end
end
