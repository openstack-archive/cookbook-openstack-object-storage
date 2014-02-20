# encoding: UTF-8
require 'chefspec'
require 'chefspec/berkshelf'

::LOG_LEVEL = :fatal
::REDHAT_OPTS = {
    platform: 'redhat',
    log_level: ::LOG_LEVEL
}
::UBUNTU_OPTS = {
    platform: 'ubuntu',
    version: '12.04',
    log_level: ::LOG_LEVEL
}

MOCK_NODE_NETWORK_DATA =
  {
    'ipaddress' => '10.0.0.2',
    'fqdn' => 'localhost.localdomain',
    'hostname' => 'localhost',
    'network' => {
      'default_interface' => 'eth0',
      'interfaces' => {
        'eth0' => {
          'addresses' => {
            'fe80::a00:27ff:feca:ab08' => { 'scope' => 'Link', 'prefixlen' => '64', 'family' => 'inet6' },
            '10.0.0.2' => { 'netmask' => '255.255.255.0', 'broadcast' => '10.0.0.255', 'family' => 'inet' },
            '08:00:27:CA:AB:08' => { 'family' => 'lladdr' }
          }
        },
        'lo' => {
          'addresses' => {
            '::1' => { 'scope' => 'Node', 'prefixlen' => '128', 'family' => 'inet6' },
            '127.0.0.1' => { 'netmask' => '255.0.0.0', 'family' => 'inet' }
          }
        }
      }
    }
  }

# TODO(chrislaco) Fixed in spec refactor
def swift_stubs # rubocop:disable MethodLength
  stub_command('/usr/bin/id swift').and_return(true)
  stub_command('[ -x /etc/swift/pull-rings.sh ]').and_return(true)
  stub_command('[ -f /etc/rsyncd.conf ]').and_return(true)
  stub_command("grep -q 'RSYNC_ENABLE=false' /etc/default/rsync").and_return(true)
  stub_command('[ -e /etc/swift/account-server.conf ] && [ -e /etc/swift/account.ring.gz ]').and_return(true)
  stub_command('[ -e /etc/swift/container-server.conf ] && [ -e /etc/swift/container.ring.gz ]').and_return(true)
  stub_command('[ -e /etc/init/swift-container-sync.conf ]').and_return(false)
  stub_command('[ -e /etc/init.d/swift-container-sync ]').and_return(false)
  stub_command('[ -e /etc/swift/object-server.conf ] && [ -e /etc/swift/object.ring.gz ]').and_return(true)
  stub_command('[ -e /etc/swift/proxy-server.conf ] && [ -e /etc/swift/object.ring.gz ]').and_return(true)

  # create mock cluster
  n = Chef::Node.new
  n.name('manager')
  n.default_attrs = {
    'swift' => {
      'service_pass' => 'foobar'
    }
  }
  Chef::Recipe.any_instance.stub(:search).with(:node, 'chef_environment:_default AND roles:swift-setup').and_return([n])
end

# README(galstrom21): This will remove any coverage warnings from
#   dependent cookbooks
ChefSpec::Coverage.filters << '*/openstack-object-storage'

at_exit { ChefSpec::Coverage.report! }
