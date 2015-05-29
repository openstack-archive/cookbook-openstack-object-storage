# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: management-server
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

# FIXME: This should probably be a role (ring-builder?), so you don't end up
# with multiple repos!
include_recipe 'openstack-object-storage::ring-repo'

platform_options = node['openstack']['object-storage']['platform']

if node['openstack']['object-storage']['authmode'] == 'swauth'
  case node['openstack']['object-storage']['swauth_source']
  when 'package'
    platform_options['swauth_packages'].each do |pkg|
      package pkg do
        action :upgrade
        options platform_options['override_options']
      end
    end
  when 'git'
    git "#{Chef::Config[:file_cache_path]}/swauth" do
      repository node['openstack']['object-storage']['swauth_repository']
      revision node['openstack']['object-storage']['swauth_version']
      action :sync
    end

    bash 'install_swauth' do
      cwd "#{Chef::Config[:file_cache_path]}/swauth"
      user 'root'
      group 'root'
      code <<-EOH
        python setup.py install
      EOH
      environment 'PREFIX' => '/usr/local'
    end
  end
end

# determine where to find dispersion login information
if node['openstack']['object-storage']['swift_secret_databag_name'].nil?
  auth_user = node['openstack']['object-storage']['dispersion']['auth_user']
  auth_user = get_password 'token', 'dispersion_auth_user' if auth_user.nil?

  auth_key  = node['openstack']['object-storage']['dispersion']['auth_key']
  auth_key = get_password 'token', 'dispersion_auth_key' if auth_key.nil?
else
  # Deprecated, else case to be removed.
  swift_secrets = Chef::EncryptedDataBagItem.load 'secrets', node['openstack']['object-storage']['swift_secret_databag_name']
  auth_user = swift_secrets['dispersion_auth_user']
  auth_key = swift_secrets['dispersion_auth_key']
end

if node['openstack']['object-storage']['statistics']['enabled']
  template platform_options['swift_statsd_publish'] do
    source 'swift-statsd-publish.py.erb'
    owner 'root'
    group 'root'
    mode 00755
  end
  cron 'cron_swift_statsd_publish' do
    command "#{platform_options['swift_statsd_publish']} > /dev/null 2>&1"
    minute "*/#{node['openstack']['object-storage']['statistics']['report_frequency']}"
  end
end

template '/etc/swift/dispersion.conf' do
  source 'dispersion.conf.erb'
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00600
  variables(
    'auth_url' => node['openstack']['object-storage']['auth_url'],
    'auth_user' => auth_user,
    'auth_key' => auth_key
  )
end
