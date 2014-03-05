# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::storage-common' do
  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @chef_run.converge 'openstack-object-storage::storage-common'
    end

    describe '/var/cache/swift' do

      before do
        @file = @chef_run.directory '/var/cache/swift'
      end

      it 'has proper owner' do
        expect(@file.owner).to eq('swift')
        expect(@file.group).to eq('swift')
      end

      it 'has proper modes' do
        expect(sprintf('%o', @file.mode)).to eq '700'
      end

    end

    describe '/etc/swift/drive-audit.conf' do

      before do
        @file = @chef_run.template '/etc/swift/drive-audit.conf'
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

  end

end
