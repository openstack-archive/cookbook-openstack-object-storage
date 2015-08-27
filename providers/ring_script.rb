# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Resource:: ring_script
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Ron Pedde <ron.pedde@rackspace.com>
#

require 'pp'

# rubocop:disable PerlBackrefs, CyclomaticComplexity, MethodLength
def generate_script # rubocop:disable Metrics/AbcSize
  # need to load and parse the existing rings.
  ports = { 'object' => node['openstack']['object-storage']['network']['object-bind-port'],
            'container' => node['openstack']['object-storage']['network']['container-bind-port'],
            'account' => node['openstack']['object-storage']['network']['account-bind-port'] }
  must_rebalance = false

  ring_path = @new_resource.ring_path
  ring_data = { raw: {}, parsed: {}, in_use: {} }
  disk_data = {}
  dirty_cluster_reasons = []

  ['account', 'container', 'object'].each do |which|
    ring_data[:raw][which] = nil

    if ::File.exist?("#{ring_path}/#{which}.builder")
      IO.popen("su swift -c 'swift-ring-builder #{ring_path}/#{which}.builder'") do |pipe|
        ring_data[:raw][which] = pipe.readlines
        Chef::Log.debug("#{which} Ring data raw:\n#{PP.pp(ring_data[:raw][which], '')}")
        ring_data[:parsed][which] = parse_ring_output(ring_data[:raw][which])
        Chef::Log.info("#{which} Ring data parsed:\n#{PP.pp(ring_data[:parsed][which], '')}")

        node.set['openstack']['object-storage']['state']['ring'][which] = ring_data[:parsed][which]
      end
    else
      Chef::Log.info("#{which} ring builder files do not exist!")
    end

    # collect all the ring data, and note what disks are in use.  All I really
    # need is a hash of device and id

    ring_data[:in_use][which] ||= {}
    if ring_data[:parsed][which][:hosts]
      ring_data[:parsed][which][:hosts].each do |_ip, dev|
        dev.each do |_dev_id, devhash|
          ring_data[:in_use][which].store(devhash[:device], devhash[:id])
        end
      end
    end

    Chef::Log.info("#{which} Ring - In use: #{PP.pp(ring_data[:in_use][which], '')}")

    # figure out what's present in the cluster
    disk_data[which] = {}
    role = node['openstack']['object-storage']["#{which}_server_chef_role"]
    disk_state = Chef::Search::Query.new.search(:node, "chef_environment:#{node.chef_environment} AND roles:#{role}")
    Chef::Log.info("#{which} node count: #{disk_state.count} for role: #{role}")

    # for a running track of available disks
    disk_data[:available] ||= {}
    disk_data[:available][which] ||= {}

    disk_state.each do |swiftnode|
      Chef::Log.info("#{which} node: #{swiftnode[:hostname]} state:\n#{PP.pp(swiftnode['openstack']['object-storage']['state'], '')}")
      if swiftnode['openstack']['object-storage']['state']['devs']
        swiftnode['openstack']['object-storage']['state']['devs'].each do |k, v|
          disk_data[which][v[:ip]] = disk_data[which][v[:ip]] || {}
          disk_data[which][v[:ip]][k] = {}
          v.keys.each { |x| disk_data[which][v[:ip]][k].store(x, v[x]) }

          disk_data[which][v[:ip]][k]['region'] = swiftnode['openstack']['object-storage']['ring']['region']
          disk_data[which][v[:ip]][k]['zone'] = swiftnode['openstack']['object-storage']['ring']['zone']

          disk_data[:available][which][v[:mountpoint]] = v[:ip]

          unless v[:mounted]
            dirty_cluster_reasons << "Disk #{v[:name]} (#{v[:uuid]}) is not mounted on host #{v[:ip]} (#{swiftnode[:hostname]})"
          end
        end
      end
    end
    Chef::Log.info("#{which} Ring - Avail:\n#{PP.pp(disk_data[:available][which], '')}")
  end

  # Have the raw data, now bump it together and drop the script

  s = "#!/bin/bash\n\n# This script is automatically generated.\n"
  s << "# Running it will likely blow up your system if you don't review it carefully.\n"
  s << "# You have been warned.\n\n"
  s << "set -x\n"
  unless node['openstack']['object-storage']['auto_rebuild_rings']
    s << "if [ \"$1\" != \"--force\" ]; then\n"
    s << "  echo \"Auto rebuild rings is disabled, so you must use --force to generate rings\"\n"
    s << "  exit 0\n"
    s << "fi\n\n"
  end

  Chef::Log.info("Disk data: #{PP.pp(disk_data, '')}")

  new_disks = {}
  missing_disks = {}
  new_servers = []

  ['account', 'container', 'object'].each do |which|
    # remove available disks that are already in the ring
    new_disks[which] = disk_data[:available][which].reject { |k, _v| ring_data[:in_use][which].key?(k) }

    # find all in-ring disks that are not in the cluster
    missing_disks[which] = ring_data[:in_use][which].reject { |k, _v| disk_data[:available][which].key?(k) }

    Chef::Log.info("#{which} Ring - Missing:\n#{PP.pp(missing_disks[which], '')}")
    Chef::Log.info("#{which} Ring - New:\n#{PP.pp(new_disks[which], '')}")

    s << "\n# -- #{which.capitalize} Servers --\n\n"
    disk_data[which].keys.sort.each do |ip|
      s << "# #{ip}\n"
      disk_data[which][ip].keys.sort.each do |k|
        v = disk_data[which][ip][k]
        s << '#  ' + v.keys.sort.select { |x| ['ip', 'device', 'uuid'].include?(x) }.map { |x| v[x] }.join(', ')
        if new_disks[which].key?(v['mountpoint'])
          s << ' (NEW!)'
          new_servers << ip unless new_servers.include?(ip)
        end
        s << "\n"
      end
    end

    # for all those servers, check if they are already in the ring.  If not,
    # then we need to add them to the ring.  For those that *were* in the
    # ring, and are no longer in the ring, we need to delete those.

    s << "\n"

    # add the new disks
    disk_data[which].keys.sort.each do |ip|
      disk_data[which][ip].keys.sort.each do |uuid|
        v = disk_data[which][ip][uuid]
        if new_disks[which].key?(v['mountpoint'])
          s << "swift-ring-builder #{ring_path}/#{which}.builder add r#{v['region']}z#{v['zone']}-#{v['ip']}:#{ports[which]}/#{v['device']} #{v['size']}\n"
          must_rebalance = true
        end
      end
    end

    # remove the disks -- sort to ensure consistent order
    missing_disks[which].keys.sort.each do |mountpoint|
      diskinfo = ring_data[:parsed][which][:hosts].select { |_k, v| v.key?(mountpoint) }.map { |_, v| v[mountpoint] }[0]
      Chef::Log.info("#{which} Missing diskinfo:\n#{PP.pp(diskinfo, '')}")
      description = Hash[diskinfo.select { |k, _v| [:zone, :ip, :device].include?(k) }].map { |k, v| "#{k}: #{v}" }.join(', ')
      s << "# #{description}\n"
      s << "swift-ring-builder #{ring_path}/#{which}.builder remove d#{missing_disks[which][mountpoint]}\n"
      must_rebalance = true
    end

    s << "\n"

    if must_rebalance
      # we'll only rebalance if we meet the minimums for new adds
      if node['openstack']['object-storage']['wait_for'] > new_servers.count
        Chef::Log.info("#{which} New servers, but not enough to force a rebalance")
        must_rebalance = false
      else
        s << "swift-ring-builder #{ring_path}/#{which}.builder rebalance\n\n\n"
      end
    else
      s << "# #{which.capitalize} ring has no outstanding changes!\n\n"
    end
  end
  [s, must_rebalance]
end

# Parse the raw output of swift-ring-builder
def parse_ring_output(ring_data)
  output = { state: {} }

  ring_data.each do |line|
    if line =~ /build version ([0-9]+)/
      output[:state][:build_version] = $1
    elsif line =~ /^Devices:\s+id\s+region\s+zone\s+/
      next
    elsif line =~ /^Devices:\s+id\s+zone\s+/
      next
    elsif line =~ /\soverload factor\s/
      next
    elsif line =~ /^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)\s+(\S+)\s+([0-9.]+)\s+(\d+)\s+([-0-9.]+)\s*$/
      output[:hosts] ||= {}
      output[:hosts][$4] ||= {}

      output[:hosts][$4][$8] ||= {}

      output[:hosts][$4][$8][:id] = $1
      output[:hosts][$4][$8][:region] = $2
      output[:hosts][$4][$8][:zone] = $3
      output[:hosts][$4][$8][:ip] = $4
      output[:hosts][$4][$8][:port] = $5
      output[:hosts][$4][$8][:replication_ip] = $6
      output[:hosts][$4][$8][:replication_port] = $7
      output[:hosts][$4][$8][:device] = $8
      output[:hosts][$4][$8][:weight] = $9
      output[:hosts][$4][$8][:partitions] = $10
      output[:hosts][$4][$8][:balance] = $11
    elsif line =~ /^\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)\s+(\S+)\s+([0-9.]+)\s+(\d+)\s+([-0-9.]+)\s*$/
      output[:hosts] ||= {}
      output[:hosts][$4] ||= {}

      output[:hosts][$4][$6] ||= {}

      output[:hosts][$4][$6][:id] = $1
      output[:hosts][$4][$6][:region] = $2
      output[:hosts][$4][$6][:zone] = $3
      output[:hosts][$4][$6][:ip] = $4
      output[:hosts][$4][$6][:port] = $5
      output[:hosts][$4][$6][:device] = $6
      output[:hosts][$4][$6][:weight] = $7
      output[:hosts][$4][$6][:partitions] = $8
      output[:hosts][$4][$6][:balance] = $9
    elsif line =~ /^\s+(\d+)\s+(\d+)\s+(\d+\.\d+\.\d+\.\d+)\s+(\d+)\s+(\S+)\s+([0-9.]+)\s+(\d+)\s+([-0-9.]+)\s*$/
      output[:hosts] ||= {}
      output[:hosts][$3] ||= {}

      output[:hosts][$3][$5] ||= {}

      output[:hosts][$3][$5][:id] = $1
      output[:hosts][$3][$5][:zone] = $2
      output[:hosts][$3][$5][:ip] = $3
      output[:hosts][$3][$5][:port] = $4
      output[:hosts][$3][$5][:device] = $5
      output[:hosts][$3][$5][:weight] = $6
      output[:hosts][$3][$5][:partitions] = $7
      output[:hosts][$3][$5][:balance] = $8
    elsif line =~ /(\d+) partitions, (\d+\.\d+) replicas, (\d+) regions, (\d+) zones, (\d+) devices, (\d+\.\d+) balance/
      output[:state][:partitions] = $1
      output[:state][:replicas] = $2
      output[:state][:regions] = $3
      output[:state][:zones] = $4
      output[:state][:devices] = $5
      output[:state][:balance] = $6
    elsif line =~ /(\d+) partitions, (\d+) replicas, (\d+) zones, (\d+) devices, (\d+\.\d+) balance$/
      output[:state][:partitions] = $1
      output[:state][:replicas] = $2
      output[:state][:zones] = $3
      output[:state][:devices] = $4
      output[:state][:balance] = $5
    elsif line =~ /^The minimum number of hours before a partition can be reassigned is (\d+)$/
      output[:state][:min_part_hours] = $1
    else
      fail "Cannot parse ring builder output for #{line}"
    end
  end

  output
end

action :ensure_exists do
  Chef::Log.info("Ensuring #{new_resource.name}")
  new_resource.updated_by_last_action(false)
  s, must_update = generate_script

  script_file = File new_resource.name do
    owner new_resource.owner
    group new_resource.group
    mode new_resource.mode
    content s
  end

  script_file.run_action(:create)
  new_resource.updated_by_last_action(must_update)
end
