# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: setup
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

include_recipe 'openstack-object-storage::common'

# make sure we die if there are multiple swift-setups
if Chef::Config[:solo]
  Chef::Application.fatal! 'This recipe uses search. Chef Solo does not support search.'
else
  setup_role = node['openstack']['object-storage']['setup_chef_role']
  setup_role_count = search(:node, "chef_environment:#{node.chef_environment} AND roles:#{setup_role}").length
  if setup_role_count > 1
    Chef::Application.fatal! 'You can only have one node with the swift-setup role'
  end
end

unless node['openstack']['object-storage']['service_pass']
  Chef::Log.info('Running swift setup - setting swift passwords')
end

platform_options = node['openstack']['object-storage']['platform']

# install platform-specific packages
platform_options['proxy_packages'].each do |pkg|
  package pkg do
    action :upgrade
    options platform_options['override_options']
  end
end

case node['openstack']['object-storage']['authmode']
when 'swauth'
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
  else
    Chef::Log.fatal("Object storage swauth source #{node['openstack']['object-storage']['swauth_source']} is not supported")
  end
when 'keystone'
  package 'python-keystoneclient' do
    action :upgrade
  end
  include_recipe 'openstack-object-storage::identity_registration'
else
  Chef::Log.fatal("Object storage authmode #{node['openstack']['object-storage']['authmode']} is not supported")
end

package 'python-swift-informant' do
  action :upgrade
  only_if { node['openstack']['object-storage']['use_informant'] }
end
