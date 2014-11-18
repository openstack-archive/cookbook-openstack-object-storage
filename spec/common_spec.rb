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

    it 'upgrades swift packages' do
      expect(chef_run).to upgrade_package('swift')
    end

    it 'does not create swift user' do
      expect(chef_run).not_to create_user('swift').with(
        shell: '/bin/bash'
      )
    end

    it 'executes pull rings' do
      expect(chef_run).to run_execute('/etc/swift/pull-rings.sh').with(
        cwd: '/etc/swift'
      )
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
      let(:file) { chef_run.template('/etc/swift/swift.conf') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates swift.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0700
        )
      end

      it 'template contents' do
        [
          /^swift_hash_path_prefix = swift_hash_path_prefix-secret$/,
          /^swift_hash_path_suffix = swift_hash_path_suffix-secret$/,
          /^max_file_size = 5368709122$/,
          /^max_meta_name_length = 128$/,
          /^max_meta_value_length = 256$/,
          /^max_meta_count = 90$/,
          /^max_meta_overall_size = 4096$/,
          /^max_header_size = 8192$/,
          /^max_object_name_length = 1024$/,
          /^container_listing_limit = 10000$/,
          /^account_listing_limit = 10000$/,
          /^max_account_name_length = 256$/,
          /^max_container_name_length = 256$/
        ].each do |content|
          expect(chef_run).to render_file(file.name).with_content(content)
        end
      end

      it 'template contents with hash overrides' do
        node.set['openstack']['object-storage']['swift_hash_path_prefix'] = '1234'
        node.set['openstack']['object-storage']['swift_hash_path_suffix'] = '4321'
        [
          /^swift_hash_path_prefix = 1234$/,
          /^swift_hash_path_suffix = 4321$/
        ].each do |content|
          expect(chef_run).to render_file(file.name).with_content(content)
        end
      end
    end

    describe '/etc/swift/pull-rings.sh' do
      let(:file) { chef_run.template('/etc/swift/pull-rings.sh') }

      it_behaves_like 'custom template banner displayer' do
        let(:file_name) { file.name }
      end

      it 'creates pull-rings.sh' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0700
        )
      end

      it 'template contents' do
        skip 'TODO: implement'
      end
    end
  end
end
