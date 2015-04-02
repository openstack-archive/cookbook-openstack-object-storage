# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: swift-common
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

class ::Chef::Recipe # rubocop:disable Documentation
  include ::Openstack
end

class Chef::Recipe # rubocop:disable Documentation
  include DriveUtils
end

include_recipe 'openstack-common::sysctl'

#-------------
# stats
#-------------

# optionally statsd daemon for stats collection
if node['openstack']['object-storage']['statistics']['enabled']
  node.set['statsd']['relay_server'] = true
  include_recipe 'statsd::server'
end

# find graphing server address
if Chef::Config[:solo] && !node['recipes'].include?('chef-solo-search')
  Chef::Log.warn('This recipe uses search. Chef Solo does not support search.')
  graphite_servers = []
else
  graphite_servers = search(:node, "roles:#{node['openstack']['object-storage']['statistics']['graphing_role']} AND chef_environment:#{node.chef_environment}")
end
graphite_host = '127.0.0.1'
unless graphite_servers.empty?
  graphite_host = graphite_servers[0]['network']["ipaddress_#{node['openstack']['object-storage']['statistics']['graphing_interface']}"]
end

if node['openstack']['object-storage']['statistics']['graphing_ip'].nil?
  node.set['statsd']['graphite_host'] = graphite_host
else
  node.set['statsd']['graphite_host'] = node['openstack']['object-storage']['statistics']['graphing_ip']
end

#--------------
# swift common
#--------------

platform_options = node['openstack']['object-storage']['platform']

platform_options['swift_packages'].each do |pkg|
  package pkg do
    options platform_options['package_overrides']
    action :upgrade
  end
end

directory '/etc/swift' do
  action :create
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00700
end

# determine hash
if node['openstack']['object-storage']['swift_secret_databag_name'].nil?
  swift_hash_path_prefix = node['openstack']['object-storage']['swift_hash_path_prefix']
  swift_hash_path_prefix = get_password 'token', 'swift_hash_path_prefix' if swift_hash_path_prefix.nil?
  swift_hash_path_suffix = node['openstack']['object-storage']['swift_hash_path_suffix']
  swift_hash_path_suffix = get_password 'token', 'swift_hash_path_suffix' if swift_hash_path_suffix.nil?
else
  # Deprecated, else case to be removed.
  swift_secrets = Chef::EncryptedDataBagItem.load 'secrets', node['openstack']['object-storage']['swift_secret_databag_name']
  swift_hash_path_prefix = swift_secrets['swift_hash']
end

template '/etc/swift/swift.conf' do
  source 'swift.conf.erb'
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00600
  variables(
    swift_hash_path_prefix: swift_hash_path_prefix,
    swift_hash_path_suffix: swift_hash_path_suffix
  )
end

# need a swift user
user node['openstack']['object-storage']['user'] do
  shell '/bin/bash'
  action :modify
end

package 'git' do
  options platform_options['package_overrides']
  action :upgrade
end

# drop a ring puller script
# TODO: make this smarter
git_builder_ip = node['openstack']['object-storage']['git_builder_ip']
template '/etc/swift/pull-rings.sh' do
  source 'pull-rings.sh.erb'
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00700
  variables(
    builder_ip: git_builder_ip,
    service_prefix: platform_options['service_prefix']
  )
end

execute '/etc/swift/pull-rings.sh' do
  cwd '/etc/swift'
  only_if '[ -x /etc/swift/pull-rings.sh ]'
end
