# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::setup' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'
    include_examples 'keystone-authmode'

    # TODO: flush out rest of this spec
  end
end
