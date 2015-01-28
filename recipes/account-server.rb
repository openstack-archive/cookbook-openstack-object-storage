# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: account-server
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

platform_options = node['openstack']['object-storage']['platform']

platform_options['account_packages'].each.each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['override_options'] # retain configs
  end
end

%w{swift-account swift-account-auditor swift-account-reaper swift-account-replicator}.each do |svc|
  service_name = platform_options['service_prefix'] + svc + platform_options['service_suffix']
  service svc do
    service_name service_name
    provider platform_options['service_provider']
    supports status: true, restart: true
    action [:enable, :start]
    only_if '[ -e /etc/swift/account-server.conf ] && [ -e /etc/swift/account.ring.gz ]'
  end
end

# create account server template
template '/etc/swift/account-server.conf' do
  source 'account-server.conf.erb'
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00600
  variables(
    'bind_ip' => node['openstack']['object-storage']['network']['account-bind-ip'],
    'bind_port' => node['openstack']['object-storage']['network']['account-bind-port']
  )

  notifies :restart, 'service[swift-account]', :immediately
  notifies :restart, 'service[swift-account-auditor]', :immediately
  notifies :restart, 'service[swift-account-reaper]', :immediately
  notifies :restart, 'service[swift-account-replicator]', :immediately
end
