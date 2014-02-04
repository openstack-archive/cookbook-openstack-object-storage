# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Library:: ip_utils
#
# Copyright 2013, ATT Inc.
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
# Author: Alan Meadows <alan.meadows@gmail.com>
#

require 'ipaddr'

# IPAddress Related Utilities
module IPUtils
  # TODO(chrislaco) This needs yanked/refactored into common/libraries/network
  def locate_ip_in_cidr(network, node) # rubocop:disable MethodLength
    Chef::Log.debug("Searching for ip within #{network} on node #{node.name}")
    net = IPAddr.new(network)
    node['network']['interfaces'].each do |interface|
      if interface[1].key?('addresses')
        interface[1]['addresses'].each do |k, v|
          if v['family'] == 'inet6' || (v['family'] == 'inet' && v['prefixlen'] != '32')
            addr = IPAddr.new(k)
            return k if net.include?(addr)
          end
        end
      end
    end

    error = "Can't find address within network #{network} for node #{node.name}"
    Chef::Log.error(error)
    fail error
  end
end
