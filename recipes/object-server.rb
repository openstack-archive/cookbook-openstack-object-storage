# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: swift-object-server
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

include_recipe 'openstack-object-storage::common'
include_recipe 'openstack-object-storage::storage-common'
include_recipe 'openstack-object-storage::disks'

class Chef::Recipe # rubocop:disable Documentation
  include ServiceUtils
end

platform_options = node['openstack']['object-storage']['platform']

platform_options['object_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['override_options']
  end
end

svc_names = {}
%w(swift-object swift-object-replicator swift-object-auditor swift-object-updater).each do |svc|
  svc_names[svc] = svc_name(svc)
end

svc_names.values.each do |svc|
  service svc do
    supports status: false, restart: true
    action [:enable, :start]
    only_if '[ -e /etc/swift/object-server.conf ] && [ -e /etc/swift/object.ring.gz ]'
  end
end

memcache_servers = memcached_servers.join ','

template '/etc/swift/object-expirer.conf' do
  source 'object-expirer.conf.erb'
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00600
  variables(
    'memcache_servers' => memcache_servers
  )
end

template '/etc/swift/object-server.conf' do
  source 'object-server.conf.erb'
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00600
  variables(
    'bind_ip' => node['openstack']['object-storage']['network']['object-bind-ip'],
    'bind_port' => node['openstack']['object-storage']['network']['object-bind-port']
  )

  notifies :restart, "service[#{svc_names['swift-object']}]", :immediately
  notifies :restart, "service[#{svc_names['swift-object-replicator']}]", :immediately
  notifies :restart, "service[#{svc_names['swift-object-updater']}]", :immediately
  notifies :restart, "service[#{svc_names['swift-object-auditor']}]", :immediately
end

cron 'swift-recon' do
  minute '*/5'
  command 'swift-recon-cron /etc/swift/object-server.conf'
  user node['openstack']['object-storage']['user']
end
