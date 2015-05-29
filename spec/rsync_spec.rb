# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::rsync' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'

    it 'upgrades git package for ring management' do
      expect(chef_run).to upgrade_package('rsync')
    end

    it 'starts rsync service on boot' do
      expect(chef_run).to enable_service('rsync')
    end

    describe '/etc/rsyncd.conf' do
      let(:file) { chef_run.template('/etc/rsyncd.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates /etc/rsyncd.conf' do
        expect(chef_run).to create_template(file.name).with(
          mode: 00644
        )
      end

      it 'template contents' do
        skip 'TODO: implement'
      end
    end
  end
end
