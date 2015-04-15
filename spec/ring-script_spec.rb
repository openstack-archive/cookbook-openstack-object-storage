# encoding: UTF-8

require_relative 'spec_helper'

describe 'openstack-object-storage::ring-repo' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) { runner.converge(described_recipe) }
    let(:events) { Chef::EventDispatch::Dispatcher.new }
    let(:cookbook_collection) { Chef::CookbookCollection.new([]) }
    let(:run_context) { Chef::RunContext.new(node, cookbook_collection, events) }

    describe 'ring_script' do
      let(:resource) do
        Chef::Resource::OpenstackObjectStorageRingScript.new('script1', run_context)
      end
      let(:provider) do
        Chef::Provider::OpenstackObjectStorageRingScript.new(resource, run_context)
      end

      it 'parse_ring_output parses ring data for normal ring data' do
        ring_data = ['/etc/swift/ring-workspace/rings/account.builder, build version 0',
                     '262144 partitions, 3.000000 replicas, 0 regions, 0 zones, 0 devices, 0.00 balance, 0.00 dispersion',
                     'The minimum number of hours before a partition can be reassigned is 1',
                     'The overload factor is 0.00% (0.000000)']
        expect(
          provider.send(:parse_ring_output, ring_data)
        ).to eq(
          state:
          { build_version: '0',
            partitions: '262144',
            replicas: '3.000000',
            regions: '0',
            zones: '0',
            devices: '0',
            balance: '0.00',
            min_part_hours: '1'
          }
        )
      end

      it 'parse_ring_output parsing fails for bad data' do
        ring_data = ['ugly data']
        exception = false
        begin
          provider.send(:parse_ring_output, ring_data)
        rescue
          exception = true
        end
        expect(exception).to be true
      end
    end
  end
end
