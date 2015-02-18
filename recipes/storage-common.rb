# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: storage-common
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

include_recipe 'openstack-object-storage::rsync'

template '/etc/swift/drive-audit.conf' do
  source 'drive-audit.conf.erb'
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00600
end

cron 'drive-audit' do
  hour node['openstack']['object-storage']['audit_hour']
  minute '10'
  command 'swift-drive-audit /etc/swift/drive-audit.conf'
end

directory '/var/cache/swift' do
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  recursive true
  action :create
  mode 00700
end
