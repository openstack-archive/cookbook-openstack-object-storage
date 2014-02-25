# encoding: UTF-8

require_relative 'spec_helper'

describe 'openstack-object-storage::sysctl' do
  describe 'ubuntu' do
    before do
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @chef_run.converge 'openstack-object-storage::sysctl'
    end

    describe '59-openstack-object-storage.conf' do
      before do
        @file = @chef_run.template '/etc/sysctl.d/59-openstack-object-storage.conf'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('root')
        expect(@file.group).to eq('root')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'sets the ipv4.tcp_tw_recycle' do
        match = 'net.ipv4.tcp_tw_recycle = 1'
        expect(@chef_run).to render_file(@file.name).with_content(match)
      end

      it 'sets the ipv4.tcp_tw_reuse' do
        match = 'net.ipv4.tcp_tw_reuse = 1'
        expect(@chef_run).to render_file(@file.name).with_content(match)
      end

      it 'sets the ipv4.tcp_syncookies' do
        match = 'net.ipv4.tcp_syncookies = 0'
        expect(@chef_run).to render_file(@file.name).with_content(match)
      end
    end
  end
end
