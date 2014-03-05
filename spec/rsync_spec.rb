# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::rsync' do
  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @chef_run.converge 'openstack-object-storage::rsync'
    end

    it 'installs git package for ring management' do
      expect(@chef_run).to install_package 'rsync'
    end

    it 'starts rsync service on boot' do
      %w{rsync}.each do |svc|
        expect(@chef_run).to enable_service(svc)
      end
    end

    describe '/etc/rsyncd.conf' do

      before do
        @file = @chef_run.template '/etc/rsyncd.conf'
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '644'
      end

      it 'template contents' do
        pending 'TODO: implement'
      end

    end

  end

end
