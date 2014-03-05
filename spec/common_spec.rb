# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::common' do
  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node

      # TODO: this does not work
      # ::Chef::Log.should_receive(:info).with('chefspec: precise-updates/havana')

      @chef_run.converge 'openstack-object-storage::common'
    end

    describe '60-openstack.conf' do
      before do
        @file = @chef_run.template '/etc/sysctl.d/60-openstack.conf'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('root')
        expect(@file.group).to eq('root')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'sets the net.ipv4.tcp_tw_recycle' do
        match = 'net.ipv4.tcp_tw_recycle = 1'
        expect(@chef_run).to render_file(@file.name).with_content(match)
      end

      it 'sets the net.ipv4.tcp_tw_reuse' do
        match = 'net.ipv4.tcp_tw_reuse = 1'
        expect(@chef_run).to render_file(@file.name).with_content(match)
      end

      it 'sets the net.ipv4.tcp_syncookies' do
        match = 'net.ipv4.tcp_syncookies = 0'
        expect(@chef_run).to render_file(@file.name).with_content(match)
      end
    end

    it 'installs git package for ring management' do
      expect(@chef_run).to install_package 'git'
    end

    describe '/etc/swift' do

      before do
        @file = @chef_run.directory '/etc/swift'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('swift')
        expect(@file.group).to eq('swift')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '700'
      end

    end

    describe '/etc/swift/swift.conf' do

      before do
        @file = @chef_run.file '/etc/swift/swift.conf'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('swift')
        expect(@file.group).to eq('swift')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '700'
      end

    end

    describe '/etc/swift/pull-rings.sh' do

      before do
        @file = @chef_run.template '/etc/swift/pull-rings.sh'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('swift')
        expect(@file.group).to eq('swift')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '700'
      end

      it 'template contents' do
        pending 'TODO: implement'
      end

    end

  end

end
