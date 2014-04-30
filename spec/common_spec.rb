# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::common' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'

    it 'includes openstack-common::sysctl' do
      expect(chef_run).to include_recipe('openstack-common::sysctl')
    end

    describe '60-openstack.conf' do
      let(:file) { chef_run.template('/etc/sysctl.d/60-openstack.conf') }

      it 'creates /etc/sysctl.d/60-openstack.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0644
        )
      end

      it 'sets the net.ipv4.tcp_tw_recycle' do
        match = 'net.ipv4.tcp_tw_recycle = 1'
        expect(chef_run).to render_file(file.name).with_content(match)
      end

      it 'sets the net.ipv4.tcp_tw_reuse' do
        match = 'net.ipv4.tcp_tw_reuse = 1'
        expect(chef_run).to render_file(file.name).with_content(match)
      end

      it 'sets the net.ipv4.tcp_syncookies' do
        match = 'net.ipv4.tcp_syncookies = 0'
        expect(chef_run).to render_file(file.name).with_content(match)
      end
    end

    it 'upgrades git package for ring management' do
      expect(chef_run).to upgrade_package('git')
    end

    describe '/etc/swift' do
      let(:dir) { chef_run.directory('/etc/swift') }

      it 'creates /etc/swift' do
        expect(chef_run).to create_directory(dir.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0700
        )
      end
    end

    describe '/etc/swift/swift.conf' do
      let(:file) { chef_run.file('/etc/swift/swift.conf') }

      it 'creates swift.conf' do
        expect(chef_run).to create_file(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0700
        )
      end

      it 'template contents' do
        pending 'TODO: implement'
      end
    end

    describe '/etc/swift/pull-rings.sh' do
      let(:file) { chef_run.template('/etc/swift/pull-rings.sh') }

      it 'creates pull-rings.sh' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0700
        )
      end

      it 'template contents' do
        pending 'TODO: implement'
      end
    end
  end
end
