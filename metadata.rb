name              'openstack-object-storage'
maintainer        'openstack-chef'
maintainer_email  'opscode-chef-openstack@googlegroups.com'
license           'Apache 2.0'
description       'Installs and configures Openstack Swift'
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           '10.1.0'

recipe            'openstack-object-storage::account-server', 'Installs the swift account server'
recipe            'openstack-object-storage::client', 'Install the swift client'
recipe            'openstack-object-storage::container-server', 'Installs the swift container server'
recipe            'openstack-object-storage::management-server', 'Installs the swift management server'
recipe            'openstack-object-storage::object-server', 'Installs the swift object server'
recipe            'openstack-object-storage::proxy-server', 'Installs the swift proxy server'
recipe            'openstack-object-storage::setup', 'Does initial setup of a swift cluster'

%w{ centos ubuntu redhat }.each do |os|
  supports os
end

depends 'memcached', '>= 1.7.2'
depends 'statsd', '>= 0.1.5'
depends 'openstack-common', '>= 10.0.0'
depends 'openstack-identity', '>= 10.0.0'
