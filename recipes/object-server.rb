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

platform_options = node['openstack']['object-storage']['platform']

platform_options['object_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['override_options']
  end
end

%w{swift-object swift-object-replicator swift-object-auditor swift-object-updater}.each do |svc|
  service_name = platform_options['service_prefix'] + svc + platform_options['service_suffix']

  service svc do
    service_name service_name
    provider platform_options['service_provider']
    # the default ubuntu provider uses invoke-rc.d, which apparently is
    # status-illy broken in ubuntu
    supports status: false, restart: true
    action [:enable, :start]
    only_if '[ -e /etc/swift/object-server.conf ] && [ -e /etc/swift/object.ring.gz ]'
  end

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

  notifies :restart, 'service[swift-object]', :immediately
  notifies :restart, 'service[swift-object-replicator]', :immediately
  notifies :restart, 'service[swift-object-updater]', :immediately
  notifies :restart, 'service[swift-object-auditor]', :immediately
end

cron 'swift-recon' do
  minute '*/5'
  command 'swift-recon-cron /etc/swift/object-server.conf'
  user node['openstack']['object-storage']['user']
end
