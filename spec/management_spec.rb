# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::management-server' do
  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @chef_run.converge 'openstack-object-storage::management-server'
    end

    it 'installs swift swauth package' do
      expect(@chef_run).to install_package 'swauth'
    end

    describe '/etc/swift/dispersion.conf' do

      before do
        @file = @chef_run.template '/etc/swift/dispersion.conf'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('swift')
        expect(@file.group).to eq('swift')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '600'
      end

      it 'template contents' do
        pending 'TODO: implement'
      end

    end

    describe '/usr/local/bin/swift-statsd-publish.py' do

      before do
        @file = @chef_run.template '/usr/local/bin/swift-statsd-publish.py'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('root')
        expect(@file.group).to eq('root')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '755'
      end

      it 'has expected statsd host' do
        expect(@chef_run).to render_file(@file.name).with_content("self.statsd_host              = '127.0.0.1'")
      end

    end

  end

end
