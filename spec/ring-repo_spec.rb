# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::ring-repo' do

  #-------------------
  # UBUNTU
  #-------------------

  describe 'ubuntu' do

    before do
      swift_stubs
      @chef_run = ::ChefSpec::Runner.new ::UBUNTU_OPTS
      @node = @chef_run.node
      @node.set['platform_family'] = 'debian'
      @node.set['lsb']['codename'] = 'precise'
      @node.set['openstack']['object-storage']['release'] = 'havana'
      @node.set['openstack']['object-storage']['authmode'] = 'swauth'
      @node.set['openstack']['object-storage']['git_builder_ip'] = '10.0.0.10'
      @chef_run.converge 'openstack-object-storage::ring-repo'
    end

    it 'installs git package for ring management' do
      expect(@chef_run).to install_package 'git-daemon-sysvinit'
    end

    it 'should not start xinetd services on boot' do
      %w{xinetd}.each do |svc|
        expect(@chef_run).not_to enable_service(svc)
      end
    end

    describe '/etc/swift/ring-workspace/generate-rings.sh' do

      it 'gets installed' do
        pending 'TODO: determine some way to ensure this LWRP script gets created'
      end

    end

  end

end
