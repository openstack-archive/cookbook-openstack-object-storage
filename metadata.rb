name              'openstack-object-storage'
maintainer        'ATT, Inc.'
license           'Apache 2.0'
description       'Installs and configures Openstack Swift'
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           '8.3.1'

recipe            'openstack-object-storage::account-server', 'Installs the swift account server'
recipe            'openstack-object-storage::client', 'Install the switch client'
recipe            'openstack-object-storage::container-server', 'Installs the swift container server'
recipe            'openstack-object-storage::object-server', 'Installs the swift object server'
recipe            'openstack-object-storage::proxy-server', 'Installs the swift proxy server'
recipe            'openstack-object-storage::setup', 'Does initial setup of a swift cluster'

%w{ centos ubuntu }.each do |os|
  supports os
end

depends           'memcached'
depends           'statsd'
depends           'apt'
depends           'openstack-common', '~> 8.0'
