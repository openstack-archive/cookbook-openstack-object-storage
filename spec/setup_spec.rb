# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::setup' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'
    include_examples 'keystone-authmode'

    it 'does not include the identity registration recipe' do
      node.set['openstack']['object-storage']['authmode'] = 'swauth'
      expect(chef_run).not_to include_recipe('openstack-object-storage::identity_registration')
    end

    it 'includes the identity registration recipe' do
      expect(chef_run).to include_recipe('openstack-object-storage::identity_registration')
    end

    # TODO: flush out rest of this spec
  end
end
