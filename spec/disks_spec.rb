# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::disks' do
  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @node.set['openstack']['object-storage']['disk_enum_expr'] = "[{ 'sda' => {}}]"
      @node.set['openstack']['object-storage']['disk_test_filter'] = [
        'candidate =~ /sd[^a]/ or candidate =~ /hd[^a]/ or candidate =~ /vd[^a]/ or candidate =~ /xvd[^a]/',
        "File.exist?('/dev/' + candidate)",
        "not system('/sbin/parted /dev/' + candidate + ' -s print | grep linux-swap')",
        "not info.has_key?('removable') or info['removable'] == 0.to_s"]

      # mock out an interface on the storage node
      @node.set['network'] = MOCK_NODE_NETWORK_DATA['network']

      @chef_run.converge 'openstack-object-storage::disks'
    end

    it 'installs xfs progs package' do
      expect(@chef_run).to install_package 'xfsprogs'
    end

    it 'installs parted package' do
      expect(@chef_run).to install_package 'parted'
    end

  end

end
