# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: rsync
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

platform_options = node['openstack']['object-storage']['platform']

platform_options['rsync_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['override_options']
  end
end

# rhel based systems install rsync and run it with rsync.  We don't want to do that
cookbook_file '/etc/init.d/rsyncd' do
  owner 'root'
  group 'root'
  mode 00755
  source 'rsync.init'
  action :create
  only_if { platform_family?('rhel') }
end

# FIXME: chicken and egg
case node['platform_family']
when 'rhel'
  # enable rsyncd
  rsync_servicename = 'rsyncd'
  service 'rsyncd' do
    supports status: false, restart: true, start: true, stop: true
    action [:enable, :start]
    only_if '[ -f /etc/rsyncd.conf ]'
  end
  # disable rsync (the one via xinetd)
  service 'rsync' do
    supports status: false, restart: false, start: false, stop: false
    action [:disable]
  end
when 'debian'
  rsync_servicename = 'rsync'
  service 'rsync' do
    supports status: false, restart: true
    action [:enable, :start]
    only_if '[ -f /etc/rsyncd.conf ]'
  end
end

template '/etc/rsyncd.conf' do
  source 'rsyncd.conf.erb'
  mode 00644
  notifies :restart, "service[#{rsync_servicename}]", :immediately
end

execute 'enable rsync' do
  command "sed -i 's/RSYNC_ENABLE=false/RSYNC_ENABLE=true/' /etc/default/rsync"
  only_if "grep -q 'RSYNC_ENABLE=false' /etc/default/rsync"
  notifies :restart, 'service[rsync]', :immediately
  action :run
  not_if { platform_family?('rhel') }
end
