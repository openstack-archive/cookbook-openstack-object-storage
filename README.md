Description
===========

Installs the OpenStack Object Storage service **Swift** as part of the OpenStack reference deployment Chef for OpenStack. The http://github.com/openstack/chef-openstack-repo contains documentation for using this cookbook in the context of a full OpenStack deployment. Swift is currently installed from packages.

https://wiki.openstack.org/wiki/Swift

Requirements
============

Clients
--------

 * CentOS >= 7
 * Ubuntu >= 14.04

Chef
---------

 * 12

Dependent Cookbooks
-------------------

 * openstack-common
 * openstack-identity
 * memcached
 * statsd

Roles
=====

 * swift-account-server - storage node for account data
 * swift-container-server - storage node for container data
 * swift-management-server - responsible for ring generation
 * swift-object-server - storage node for object server
 * swift-proxy-server - proxy for swift storage nodes
 * swift-setup - server responsible for generating initial settings

The swift-management-server role performs the following functions:

 * proxy node that knows super admin password
 * ring repository and ring building workstation
 * generally always has the swift-setup role too
 * there can only be _one_ swift-management-server

There *must* be a node with the the swift-management-server role to act
as the ring repository.

In small environments, it is likely that all storage machines will
have all-in-one roles, with a load balancer ahead of it

In larger environments, where it is cost effective to split the proxy
and storage layer, storage nodes will carry
swift-{account,container,object}-server roles, and there will be
dedicated hosts with the swift-proxy-server role.

In really really huge environments, it's possible that the storage
node will be split into swift-{container,account}-server nodes and
swift-object-server nodes.

Recipes
=======

client
----
- Install the swift client packages

Attributes
==========

There are other attributes that must be set depending on authmode.
For "swauth", the following attributes are used:

 * ```default[:swift][:authkey]``` - swauth super admin key if using swauth (defaults to test)

The following secrets can be defined in the databag defined in Common ['openstack']['secret']['secrets_data_bag']

```
        {
          "swift_hash": "1a7c0568fa84"
          "swift_authkey": "keY4all"
          "dispersion_auth_user": "ops:dispersion",
          "dispersion_auth_key": "dispersionpass"
        }
```

In addition, because swift is typically deployed as a cluster
there are some attributes used to find interfaces and ip addresses
on storage nodes:

 * ```default[:swift][:git_builder_ip]``` - the IP address of the management server which other cluster members will use as their git pull target for ring updates (defaults to 127.0.0.1)
 * ```default[:swift][:network][:proxy-bind-ip]``` - the IP address to bind to
   on the proxy servers (defaults to 0.0.0.0 for all addresses)
 * ```default[:swift][:network][:proxy-bind-port]``` - the port to bind to
   on the proxy servers (defaults to 8080)
 * ```default[:swift][:network][:account-bind-ip]``` - the IP address to bind to
   on the account servers (defaults to 0.0.0.0 for all addresses)
 * ```default[:swift][:network][:account-bind-port]``` - the port to bind to
   on the account servers (defaults to 6002)
 * ```default[:swift][:network][:container-bind-ip]``` - the IP address to bind to
   on the container servers (defaults to 0.0.0.0 for all addresses)
 * ```default[:swift][:network][:container-bind-port]``` - the port to bind to
   on the container servers (defaults to 6002)
 * ```default[:swift][:network][:object-bind-ip]``` - the IP address to bind to
   on the object servers (defaults to 0.0.0.0 for all addresses)
 * ```default[:swift][:network][:object-bind-port]``` - the port to bind to
   on the container servers (defaults to 6002)
 * ```default[:swift][:network][:object-cidr]``` - the CIDR network for your object
   servers in order to build the ring (defaults to 10.0.0.0/24)

Proxy Plugins
=============

Formpost
-------

 * ```default[:swift][:formpost][:enabled]``` - optionally enable the formpost proxy plugin (defaults to false)

TempURL
-------

 * ```default[:swift][:tempurl][:enabled]``` - optionally enable the tempurl proxy plugin (defaults to false)
 * ```default[:swift][:tempurl][:incoming_remove_headers]``` - The headers to remove from incoming requests (defaults to x-timestamp)
 * ```default[:swift][:tempurl][:incoming_allow_headers]``` - The headers allowed as exceptions to incoming_remove_headers (defaults to empty string)
 * ```default[:swift][:tempurl][:incoming_allow_headers]``` - The headers allowed as exceptions to incoming_remove_headers (defaults to empty string)
 * ```default[:swift][:tempurl][:outgoing_remove_headers]``` - The headers to remove from outgoing responses (defaults to x-object-meta-*)
 * ```default[:swift][:tempurl][:outgoing_allow_headers]``` - The headers allowed as exceptions to outgoing_remove_headers (defaults x-object-meta-public-*)

Domain Remap
------------

 * ```default[:swift][:domain_remap][:enabled]``` - optionally enable the domain remap proxy plugin (defaults to false)
 * ```default[:swift][:domain_remap][:storage_domain]``` - The domain remap reseller domain (defaults to example.com)
 * ```default[:swift][:domain_remap][:root_path]``` - The domain remap root path (defaults to v1)
 * ```default[:swift][:domain_remap][:reseller_prefixes]``` - The domain remap reseller prefixes (defaults to AUTH)

Staticweb
----------

 * ```default[:swift][:staticweb][:enabled]``` - optionally enable the staticweb proxy plugin (defaults to false)
 * ```default[:swift][:staticweb][:cache_timeout]``` - Seconds to cache container x-container-meta-web-* header values (defaults to 300)

Examples
========

Example environment
-------------------

```json
{
  "default_attributes": {
    "swift": {
        "swift_hash": "107c0568ea84",
        "authmode": "swauth",
        "authkey": "test",
        "auto_rebuild_rings": false,
        "git_builder_ip": "10.0.0.10",
        "swauth": {
            "url": "http://10.0.0.10:8080/v1/"
      }
    }
  },
  "name": "swift",
  "chef_type": "environment",
  "json_class": "Chef::Environment"
}
```

This sets up defaults for a swauth-based cluster with the storage
network on 10.0.0.0/24.

Standalone Storage Server
-------------------------

```json
{
  "name": "swift-object-server",
  "json_class": "Chef::Role",
  "run_list": [
    "recipe[swift::object-server]"
  ],
  "description": "A storage server role.",
  "chef_type": "role"
}
```

Standalone Proxy Server
-----------------------

```json
  "run_list": [
    "role[swift-proxy-server]"
  ]
```

Testing
=======

Please refer to the [TESTING.md](TESTING.md) for instructions for testing the cookbook.

Berkshelf
=========

Berks will resolve version requirements and dependencies on first run and
store these in Berksfile.lock. If new cookbooks become available you can run
`berks update` to update the references in Berksfile.lock. Berksfile.lock will
be included in stable branches to provide a known good set of dependencies.
Berksfile.lock will not be included in development branches to encourage
development against the latest cookbooks.

License and Author
==================

|                      |                                                    |
|:---------------------|:---------------------------------------------------|
| **Author**           |  Alan Meadows (<alan.meadows@gmail.com>)           |
| **Author**           |  Oisin Feeley (<of3434@att.com>)                   |
| **Author**           |  Ron Pedde (<ron.pedde@rackspace.com>)             |
| **Author**           |  Will Kelly (<will.kelly@rackspace.com>)           |
| **Author**           |  Chen Zhiwei (<zhiwchen@cn.ibm.com>)               |
| **Author**           |  Mark Vanderwiel (<vanderwl@us.ibm.com>)           |
| **Author**           |  Jan Klare (<j.klare@x-ion.de>)                    |
|                      |                                                    |
| **Copyright**        |  Copyright (c) 2013, AT&T, Inc.                    |
| **Copyright**        |  Copyright (c) 2012, Rackspace US, Inc.            |
| **Copyright**        |  Copyright (c) 2013-2015 IBM, Corp.                |

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
