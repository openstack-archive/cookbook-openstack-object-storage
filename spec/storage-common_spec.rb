# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::storage-common' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'

    describe '/var/cache/swift' do
      let(:dir) { chef_run.directory('/var/cache/swift') }

      it 'creates /var/cache/swift' do
        expect(chef_run).to create_directory(dir.name).with(
          user: 'swift',
          group: 'swift',
          mode: 00700
        )
      end
    end

    describe '/etc/swift/drive-audit.conf' do
      let(:file) { chef_run.template('/etc/swift/drive-audit.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates drive-audit.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 00600
        )
      end

      it 'template contents' do
        skip 'TODO: implement'
      end
    end
  end
end
