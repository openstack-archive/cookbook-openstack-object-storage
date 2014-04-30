# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::ring-repo' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'

    it 'upgrades git package for ring management' do
      expect(chef_run).to upgrade_package('git-daemon-sysvinit')
    end

    it 'should not start xinetd services on boot' do
      %w{xinetd}.each do |svc|
        expect(chef_run).not_to enable_service(svc)
      end
    end

    # FIXME(galstrom21): This spec file should just check that the LWRP
    #   is called with the appropriate paramaters. It should not be checking
    #   the file contents.
    describe '/etc/swift/ring-workspace/generate-rings.sh' do
      it 'gets installed' do
        pending 'TODO: determine some way to ensure this LWRP script gets created'
      end
    end
  end
end
