# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Recipe:: proxy-server
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
include_recipe 'openstack-object-storage::memcached'

class Chef::Recipe # rubocop:disable Documentation
  include IPUtils
  include ServiceUtils
end

if node.run_list.expand(node.chef_environment).recipes.include?('openstack-object-storage::setup')
  Chef::Log.info('I ran the openstack-object-storage::setup so I will use my own swift passwords')
else
  setup_role = node['openstack']['object-storage']['setup_chef_role']
  setup = search(:node, "chef_environment:#{node.chef_environment} AND roles:#{setup_role}")
  if setup.length == 0
    Chef::Application.fatal! 'You must have run the openstack-object-storage::setup recipe (on this or another node) before running the swift::proxy recipe on this node'
  elsif setup.length == 1
    Chef::Log.info "Found openstack-object-storage::setup node: #{setup[0].name}"
    node.set['openstack']['object-storage']['service_pass'] = setup[0]['swift']['service_pass']
  elsif setup.length > 1
    Chef::Application.fatal! 'You have multiple nodes in your environment that have run swift-setup, and that is not allowed'
  end
end

platform_options = node['openstack']['object-storage']['platform']

# upgrade platform-specific packages
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
  end
when 'keystone'
  package 'python-keystoneclient' do
    action :upgrade
  end
  identity_endpoint = internal_endpoint 'identity-internal'
  identity_admin_endpoint = admin_endpoint 'identity-admin'
  service_pass = get_password 'service', 'openstack-object-storage'

  auth_uri = auth_uri_transform identity_endpoint.to_s, node['openstack']['object-storage']['api']['auth']['version']
  identity_uri = identity_uri_transform(identity_admin_endpoint)
end

package 'python-swift-informant' do
  action :upgrade
  only_if { node['openstack']['object-storage']['use_informant'] }
end

directory '/var/cache/swift' do
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00700
end

proxy_service_name = svc_name('swift-proxy')
service proxy_service_name do
  supports status: true, restart: true
  action [:enable, :start]
  only_if '[ -e /etc/swift/proxy-server.conf ] && [ -e /etc/swift/object.ring.gz ]'
end

# determine authkey to use
if node['openstack']['object-storage']['swift_secret_databag_name'].nil?
  authkey = node['openstack']['object-storage']['authkey']
  authkey = get_password 'token', 'swift_authkey' if authkey.nil?
else
  # Deprecated, else case to be removed.
  swift_secrets = Chef::EncryptedDataBagItem.load 'secrets', node['openstack']['object-storage']['swift_secret_databag_name']
  authkey = swift_secrets['swift_authkey']
end

proxy_api_bind = endpoint 'object-storage-api-bind'

proxy_api_bind_port = node['openstack']['object-storage']['network']['proxy-bind-port']
proxy_api_bind_port = proxy_api_bind.port if proxy_api_bind_port.nil?
proxy_api_bind_host = node['openstack']['object-storage']['network']['proxy-bind-ip']
proxy_api_bind_host = proxy_api_bind.host if proxy_api_bind_host.nil?

memcache_servers = memcached_servers.join ','

# create proxy config file
template '/etc/swift/proxy-server.conf' do
  source 'proxy-server.conf.erb'
  owner node['openstack']['object-storage']['user']
  group node['openstack']['object-storage']['group']
  mode 00600
  variables(
    'authmode' => node['openstack']['object-storage']['authmode'],
    'bind_host' => proxy_api_bind_host,
    'bind_port' => proxy_api_bind_port,
    'authkey' => authkey,
    'memcache_servers' => memcache_servers,
    'auth_uri' => auth_uri,
    'identity_uri' => identity_uri,
    'service_pass' => service_pass
  )
  notifies :restart, "service[#{proxy_service_name}]", :immediately
end
