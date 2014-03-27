# encoding: UTF-8
# TODO(chrislaco) This file needs the stock chef header/copyright
#--------------------
# node/ring settings
#--------------------

default['openstack']['object-storage']['state'] = {}
default['openstack']['object-storage']['swift_hash'] = '107c0568ea84'
default['openstack']['object-storage']['audit_hour'] = '5'
default['openstack']['object-storage']['disk_enum_expr'] = 'node[:block_device]'
default['openstack']['object-storage']['auto_rebuild_rings'] = false
default['openstack']['object-storage']['git_builder_ip'] = '127.0.0.1'

# the release only has any effect on ubuntu, and must be
# a valid release on http://ubuntu-cloud.archive.canonical.com/ubuntu
default['openstack']['object-storage']['release'] = 'icehouse'

# we support an optional secret databag where we will retrieve the
# following attributes overriding any default attributes here
#
# {
#   "id": "swift_dal2",
#   "swift_hash": "107c0568ea84"
#   "swift_authkey": "keW4all"
#   "dispersion_auth_user": "test:test",
#   "dispersion_auth_key": "test"
# }
default['openstack']['object-storage']['swift_secret_databag_name'] = nil

#--------------------
# roles
#--------------------

default['openstack']['object-storage']['setup_chef_role']             = 'swift-setup'
default['openstack']['object-storage']['management_server_chef_role'] = 'swift-management-server'
default['openstack']['object-storage']['proxy_server_chef_role']      = 'swift-proxy-server'
default['openstack']['object-storage']['object_server_chef_role']     = 'swift-object-server'
default['openstack']['object-storage']['account_server_chef_role']    = 'swift-account-server'
default['openstack']['object-storage']['container_server_chef_role']  = 'swift-container-server'

#--------------------
# authentication
#--------------------

default['openstack']['object-storage']['authmode']              = 'swauth'
default['openstack']['object-storage']['authkey']               = 'test'
default['openstack']['object-storage']['swift_url']             = 'http://127.0.0.1:8080/v1/'
default['openstack']['object-storage']['swauth_url']            = 'http://127.0.0.1:8080/v1/'
default['openstack']['object-storage']['auth_url']              = 'http://127.0.0.1:8080/auth/v1.0'

#---------------------
# dispersion settings
#---------------------

default['openstack']['object-storage']['dispersion']['auth_user'] = 'test:test'
default['openstack']['object-storage']['dispersion']['auth_key'] = 'test'

# settings for the swift ring - these default settings are
# a safe setting for testing but part_power should be set to
# 26 in production to allow a swift cluster with 50,000 spindles
default['openstack']['object-storage']['ring']['part_power'] = 18
default['openstack']['object-storage']['ring']['min_part_hours'] = 1
default['openstack']['object-storage']['ring']['replicas'] = 3

#------------------
# statistics
#------------------
default['openstack']['object-storage']['statistics']['enabled'] = true
default['openstack']['object-storage']['statistics']['sample_rate'] = 1

# there are two ways to discover your graphite server ip for
# statsd to periodically publish to.  You can directly set
# the ip below, or leave it set to nil and supply chef with
# the role name of your graphite server and the interface
# name to retrieve the appropriate internal ip address from
#
# if no servers with the role below can be found then
# 127.0.0.1 will be used
default['openstack']['object-storage']['statistics']['graphing_ip']  = nil
default['openstack']['object-storage']['statistics']['graphing_role'] = 'graphite-role'
default['openstack']['object-storage']['statistics']['graphing_interface'] = 'eth0'

# how frequently to run chef instantiated /usr/local/bin/swift_statsd_publish.py
# which publishes dispersion and recon statistics (in minutes)
default['openstack']['object-storage']['statistics']['report_frequency'] = 15

# enable or disable specific portions of generated report
default['openstack']['object-storage']['statistics']['enable_dispersion_report'] = true
default['openstack']['object-storage']['statistics']['enable_recon_report'] = true
default['openstack']['object-storage']['statistics']['enable_disk_report'] = true

# settings for statsd which should be configured to use the local
# statsd daemon that chef will install if statistics are enabled
default['openstack']['object-storage']['statistics']['statsd_host'] = '127.0.0.1'
default['openstack']['object-storage']['statistics']['statsd_port'] = '8125'
default['openstack']['object-storage']['statistics']['statsd_prefix'] = 'openstack.swift'

# paths to the recon cache files
default['openstack']['object-storage']['statistics']['recon_account_cache'] = '/var/cache/swift/account.recon'
default['openstack']['object-storage']['statistics']['recon_container_cache'] = '/var/cache/swift/container.recon'
default['openstack']['object-storage']['statistics']['recon_object_cache'] = '/var/cache/swift/object.recon'

#------------------
# network settings
#------------------

# the cidr configuration items are unimportant for a single server
# configuration, but in a multi-server setup, the cidr should match
# the interface appropriate to that service as they are used to
# resolve the appropriate addresses to use for internode
# communication

# proxy servers
default['openstack']['object-storage']['network']['proxy-bind-ip']	        = '0.0.0.0'
default['openstack']['object-storage']['network']['proxy-bind-port'] 	        = '8080'
default['openstack']['object-storage']['network']['proxy-cidr']               = '10.0.0.0/24'

# account servers
default['openstack']['object-storage']['network']['account-bind-ip']	        = '0.0.0.0'
default['openstack']['object-storage']['network']['account-bind-port']        = '6002'

# container servers
default['openstack']['object-storage']['network']['container-bind-ip']	= '0.0.0.0'
default['openstack']['object-storage']['network']['container-bind-port']      = '6001'

# object servers
default['openstack']['object-storage']['network']['object-bind-ip']	        = '0.0.0.0'
default['openstack']['object-storage']['network']['object-bind-port']         = '6000'
default['openstack']['object-storage']['network']['object-cidr']              = '10.0.0.0/24'

#------------------
# sysctl
#------------------

# set sysctl properties for time waits
default['openstack']['sysctl']['net.ipv4.tcp_tw_recycle'] = 1
default['openstack']['sysctl']['net.ipv4.tcp_tw_reuse'] = 1
default['openstack']['sysctl']['net.ipv4.tcp_syncookies'] = 0

# N.B. conntrack_max may also need to be adjusted if
# server is running a stateful firewall

#------------------
# disk search
#------------------

# disk_test_filter is an array of predicates to test against disks to
# determine if a disk should be formatted and configured for swift.
# Each predicate is evaluated in turn, and a false from the predicate
# will result in the disk not being considered as a candidate for
# formatting.
default['openstack']['object-storage']['disk_test_filter'] = [
    'candidate =~ /(sd|hd|xvd|vd)(?!a$)[a-z]+/',
    "File.exist?('/dev/' + candidate)",
    "not system('/sbin/parted /dev/' + candidate + ' -s print | grep linux-swap')",
    "not info.has_key?('removable') or info['removable'] == 0.to_s"]

#-------------------
# template overrides
#-------------------

# proxy-server

# enable or disable formpost
default['openstack']['object-storage']['formpost']['enabled'] = false

# enable or disable tempurl
default['openstack']['object-storage']['tempurl']['enabled'] = false

# The headers to remove from incoming requests. Simply a whitespace delimited
# list of header names and names can optionally end with '*' to indicate a
# prefix match. incoming_allow_headers is a list of exceptions to these
# removals.
default['openstack']['object-storage']['tempurl']['incoming_remove_headers'] = 'x-timestamp'

# The headers allowed as exceptions to incoming_remove_headers. Simply a
# whitespace delimited list of header names and names can optionally end with
# '*' to indicate a prefix match.
default['openstack']['object-storage']['tempurl']['incoming_allow_headers'] = ''

# The headers to remove from outgoing responses. Simply a whitespace delimited
# list of header names and names can optionally end with '*' to indicate a
# prefix match. outgoing_allow_headers is a list of exceptions to these
# removals.
default['openstack']['object-storage']['tempurl']['outgoing_remove_headers'] = 'x-object-meta-*'

# The headers allowed as exceptions to outgoing_remove_headers. Simply a
# whitespace delimited list of header names and names can optionally end with
# '*' to indicate a prefix match.
default['openstack']['object-storage']['tempurl']['outgoing_allow_headers'] = 'x-object-meta-public-*'

# enable or disable domain_remap
default['openstack']['object-storage']['domain_remap']['enabled'] = false

# enable domain log name
default['openstack']['object-storage']['domain_remap']['log_name'] = 'domain_remap'

# domain remap log facilty
default['openstack']['object-storage']['domain_remap']['log_facility'] = 'LOG_LOCAL0'

# domain remap log level
default['openstack']['object-storage']['domain_remap']['log_level'] = 'INFO'

# domain remap log headers
default['openstack']['object-storage']['domain_remap']['log_headers'] = 'False'

# domain remap reseller domain
default['openstack']['object-storage']['domain_remap']['storage_domain'] = 'example.com'

# domain remap root path
default['openstack']['object-storage']['domain_remap']['path_root'] = 'v1'

# domain remap reseller prefixes
default['openstack']['object-storage']['domain_remap']['reseller_prefixes'] = 'AUTH'

# whether or not to enable staticweb in the swift proxy
default['openstack']['object-storage']['staticweb']['enabled'] = false

# Seconds to cache container x-container-meta-web-* header values.
default['openstack']['object-storage']['staticweb']['cache_timeout'] = 300

# staticweb logging options
default['openstack']['object-storage']['staticweb']['log_facility'] = 'LOG_LOCAL0'
default['openstack']['object-storage']['staticweb']['log_level'] = 'INFO'
default['openstack']['object-storage']['staticweb']['access_log_name'] = 'staticweb'
default['openstack']['object-storage']['staticweb']['access_log_facility'] = 'LOG_LOCAL0'
default['openstack']['object-storage']['staticweb']['access_log_level'] = 'INFO'
default['openstack']['object-storage']['staticweb']['log_headers'] = 'False'

# container-server

# Override this with an allowed list of your various swift clusters if you wish
# to enable container sync for your end-users between clusters.  This should
# be an array of fqdn hostnames for the cluster end-points that your end-users
# would access in the format of ['host1', 'host2', 'host3']
default['openstack']['object-storage']['container-server']['allowed_sync_hosts'] = []

# container-sync logging settings
default['openstack']['object-storage']['container-server']['container-sync']['log_name'] = 'container-sync'
default['openstack']['object-storage']['container-server']['container-sync']['log_facility'] = 'LOG_LOCAL0'
default['openstack']['object-storage']['container-server']['container-sync']['log_level'] = 'INFO'

# If you need to use an HTTP Proxy, set it here; defaults to no proxy.
default['openstack']['object-storage']['container-server']['container-sync']['sync_proxy'] = nil

# Will sync, at most, each container once per interval (in seconds)
default['openstack']['object-storage']['container-server']['container-sync']['interval'] = 300

# Maximum amount of time to spend syncing each container per pass (in seconds)
default['openstack']['object-storage']['container-server']['container-sync']['container_time'] = 60

#------------------
# swauth source
# -----------------
# Versions of swauth in Ubuntu Cloud Archive PPA can be outdated. This
# allows us to chose to install directly from a tagged branch of
# gholt's repository.
# values:  package, git
default['openstack']['object-storage']['swauth_source'] = 'package'
default['openstack']['object-storage']['swauth_repository'] = 'https://github.com/gholt/swauth.git'
default['openstack']['object-storage']['swauth_version'] = '1.0.8'

#------------------
# packages
#------------------

# Leveling between distros
case platform
when 'redhat'
  default['openstack']['object-storage']['platform'] = {
    'disk_format' => 'ext4',
    'proxy_packages' => %w{openstack-swift-proxy sudo cronie python-memcached},
    'object_packages' => ['openstack-swift-object', 'sudo', 'cronie'],
    'container_packages' => ['openstack-swift-container', 'sudo', 'cronie'],
    'account_packages' => ['openstack-swift-account', 'sudo', 'cronie'],
    'swift_packages' => ['openstack-swift', 'sudo', 'cronie'],
    'swift_client_packages' => ['python-swiftclient'],
    'swauth_packages' => ['openstack-swauth', 'sudo', 'cronie'],
    'rsync_packages' => ['rsync'],
    'git_packages' => ['xinetd', 'git', 'git-daemon'],
    'service_prefix' => 'openstack-',
    'service_suffix' => '',
    'git_dir' => '/var/lib/git',
    'git_service' => 'git',
    'service_provider' => Chef::Provider::Service::Redhat,
    'override_options' => '',
    'swift_statsd_publish' => '/usr/bin/swift-statsd-publish.py'
  }
#
# python-iso8601 is a missing dependency for swift.
# https://bugzilla.redhat.com/show_bug.cgi?id=875948
when 'centos'
  default['openstack']['object-storage']['platform'] = {
    'disk_format' => 'xfs',
    'proxy_packages' => %w{openstack-swift-proxy sudo cronie python-iso8601 python-memcached},
    'object_packages' => %w{openstack-swift-object sudo cronie python-iso8601},
    'container_packages' => %w{openstack-swift-container sudo cronie python-iso8601},
    'account_packages' => %w{openstack-swift-account sudo cronie python-iso8601},
    'swift_packages' => %w{openstack-swift sudo cronie python-iso8601},
    'swift_client_packages' => ['python-swiftclient'],
    'swauth_packages' => %w{openstack-swauth sudo cronie python-iso8601},
    'rsync_packages' => ['rsync'],
    'git_packages' => ['xinetd', 'git', 'git-daemon'],
    'service_prefix' => 'openstack-',
    'service_suffix' => '',
    'git_dir' => '/var/lib/git',
    'git_service' => 'git',
    'service_provider' => Chef::Provider::Service::Redhat,
    'override_options' => '',
    'swift_statsd_publish' => '/usr/bin/swift-statsd-publish.py'
  }
when 'fedora'
  default['openstack']['object-storage']['platform'] = {
    'disk_format' => 'xfs',
    'proxy_packages' => ['openstack-swift-proxy', 'python-memcached'],
    'object_packages' => ['openstack-swift-object'],
    'container_packages' => ['openstack-swift-container'],
    'account_packages' => ['openstack-swift-account'],
    'swift_packages' => ['openstack-swift'],
    'swift_client_packages' => ['python-swiftclient'],
    'swauth_packages' => ['openstack-swauth'],
    'rsync_packages' => ['rsync'],
    'git_packages' => ['git', 'git-daemon'],
    'service_prefix' => 'openstack-',
    'service_suffix' => '.service',
    'git_dir' => '/var/lib/git',
    'git_service' => 'git',
    'service_provider' => Chef::Provider::Service::Systemd,
    'override_options' => '',
    'swift_statsd_publish' => '/usr/bin/swift-statsd-publish.py'
  }
when 'ubuntu'
  default['openstack']['object-storage']['platform'] = {
    'disk_format' => 'xfs',
    'proxy_packages' => ['swift-proxy', 'python-memcache'],
    'object_packages' => ['swift-object'],
    'container_packages' => ['swift-container'],
    'account_packages' => ['swift-account', 'python-swiftclient'],
    'swift_packages' => ['swift'],
    'swift_client_packages' => ['python-swiftclient'],
    'swauth_packages' => ['swauth'],
    'rsync_packages' => ['rsync'],
    'git_packages' => ['git-daemon-sysvinit'],
    'service_prefix' => '',
    'service_suffix' => '',
    'git_dir' => '/var/cache/git',
    'git_service' => 'git-daemon',
    'service_provider' => Chef::Provider::Service::Upstart,
    'override_options' => "-o Dpkg::Options:='--force-confold' -o Dpkg::Option:='--force-confdef'",
    'swift_statsd_publish' => '/usr/local/bin/swift-statsd-publish.py'
  }
end
