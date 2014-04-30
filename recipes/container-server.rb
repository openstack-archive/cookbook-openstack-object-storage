# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: swift-container-server
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

platform_options['container_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['override_options']
  end
end

# epel/f-17 missing init scripts for the non-major services.
# https://bugzilla.redhat.com/show_bug.cgi?id=807170
%w{auditor updater replicator}.each do |svc|
  template "/etc/systemd/system/openstack-swift-container-#{svc}.service" do
    owner 'root'
    group 'root'
    mode '0644'
    source 'simple-systemd-config.erb'
    variables(
      description: 'OpenStack Object Storage (swift) - ' +
                  "Container #{svc.capitalize}",
      user: 'swift',
      exec: "/usr/bin/swift-container-#{svc} " +
            '/etc/swift/container-server.conf'
    )
    only_if { platform?('fedora') }
  end
end

# TODO(breu): track against upstream epel packages to determine if this
# is still necessary
# https://bugzilla.redhat.com/show_bug.cgi?id=807170
%w{auditor updater replicator}.each do |svc|
  template "/etc/init.d/openstack-swift-container-#{svc}" do
    owner 'root'
    group 'root'
    mode '0755'
    source 'simple-redhat-init-config.erb'
    variables(
      description: 'OpenStack Object Storage (swift) - ' +
                   "Container #{svc.capitalize}",
      exec: "container-#{svc}"
    )
    only_if { platform?('redhat', 'centos') }
  end
end

%w{swift-container swift-container-auditor swift-container-replicator swift-container-updater}.each do |svc|
  service_name = platform_options['service_prefix'] + svc + platform_options['service_suffix']

  service svc do
    service_name service_name
    provider platform_options['service_provider']
    supports status: true, restart: true
    action [:enable, :start]
    only_if '[ -e /etc/swift/container-server.conf ] && [ -e /etc/swift/container.ring.gz ]'
  end
end

template '/etc/swift/container-server.conf' do
  source 'container-server.conf.erb'
  owner 'swift'
  group 'swift'
  mode 0600
  variables(
    'bind_ip' => node['openstack']['object-storage']['network']['container-bind-ip'],
    'bind_port' => node['openstack']['object-storage']['network']['container-bind-port']
  )

  notifies :restart, 'service[swift-container]', :immediately
  notifies :restart, 'service[swift-container-replicator]', :immediately
  notifies :restart, 'service[swift-container-updater]', :immediately
  notifies :restart, 'service[swift-container-auditor]', :immediately
end

# Ubuntu 12.04 packages are missing the swift-container-sync service scripts
# See https://bugs.launchpad.net/cloud-archive/+bug/1250171
if platform?('ubuntu')
  cookbook_file '/etc/init/swift-container-sync.conf' do
    owner 'root'
    group 'root'
    mode 0755
    source 'swift-container-sync.conf.upstart'
    action :create
    not_if '[ -e /etc/init/swift-container-sync.conf ]'
  end
  link '/etc/init.d/swift-container-sync' do
    to '/lib/init/upstart-job'
    not_if '[ -e /etc/init.d/swift-container-sync ]'
  end
end

service_name = platform_options['service_prefix'] + 'swift-container-sync' + platform_options['service_suffix']
unless node['openstack']['object-storage']['container-server']['allowed_sync_hosts'] == []
  service 'swift-container-sync' do
    service_name service_name
    provider platform_options['service_provider']
    supports status: false, restart: true
    action [:enable, :start]
    only_if '[ -e /etc/swift/container-server.conf ] && [ -e /etc/swift/container.ring.gz ]'
  end
end
