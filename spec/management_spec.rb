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

      it 'creates dispersion.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0600
        )
      end

      it 'template contents' do
        pending 'TODO: implement'
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
