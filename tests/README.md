Swift Vagrant Cluster
=====================

Overview
--------

Swift is designed to work in a cluster, and sometimes issues with recipes 
won't be seen unless there are several servers configured with this cookbook
along with several disks.  Keep in mind, it is relatively time intensive to 
setup this cluster so basic development testing should be done first by 
running ```./run_tests.bash``` in the cookbook root in order to flush out
obvious issues before moving on to integration testing in the live Vagrant
cluster.  

In order to help developers debug and test this cookbook and its recipes, 
the scripts in this directory attempt to help  developers setup their own 
cluster quickly and easily. This directory contains scripts that will help 
create a working swift cluster.  It is designed to require nothing more then 
Berkshelf and Vagrant with as little disruption to the developers local 
workstation as possible. 

The cluster.sh script is designed to build a development swift cluster 
from scratch based on the Ubuntu Precise 64 image.  You should be able 
to safely run it from your development workstation.  It performs the following:

1. Calls berks install and places the cookbooks and dependencies in /tmp
1. Instantiates a chefserver at 10.0.0.2
1. Loads the environmental test data (environment, roles, etc) into chefserver
1. Loads your checked out swift cookbook into chefserver
1. Creates a local knife client config you can use to interact with chef server
1. Instantiates a storage1 server at 10.0.0.10
1. Attaches 5 additional disks to storage1
1. Instantiates a storage2 server at 10.0.0.11
1. Attaches 5 additional disks to storage2
1. Instantiates a storage3 server at 10.0.0.11
1. Attaches 5 additional disks to storage3
1. Forces ring build and distribution to activate all services
1. Prepares swauth, allowing you to login to 10.0.0.10 as test:test with key test
  
You will then be able to externally access your cluster:

    $ swift -U 'test:test' -K test http://10.0.0.10:8080/auth/v1.0 stat

Cluster Commands
----------------

The cluster.sh utility is designed to aid in the development and testing
of this cookbook.  The cluster makes certain calls to Berkshelf which imply 
a certain current working directory.  All cluster commands should be called 
from the repository root as your working directory. 

In other words, do not ```cd tests; ./cluster.sh``` but instead call ```tests/cluster.sh```

It supports the following helpful commands:

    $ tests/cluster.sh run

Cleanup any left over artifacts and run the cluster, creating virtual
machines, loading the chef server, and starting all storage nodes as 
well as attaching their disks.

    $ tests/cluster.sh clean

This will shutdown and purge all virtual machines, disks, and cookbooks
that have been stored in /tmp.

    $ tests/cluster.sh refresh_clients

Any changes to your copy of the swift cookbook can be easily pushed to the chef
server and ran on all clients (calls chef-client) by calling this.  Any errors with the cookbooks
will be displayed.

    $ tests/cluster.sh reload_chef

Push changes to the chef server without forcing clients to re-run chef-client.

Cluster Chef Server
-------------------

You can interact directly with the clusters chef server with knife using the
credentials created at /tmp/swiftknife.rb after a cluster.sh run:

```
$ knife node list -c /tmp/swiftknife.rb 
  storage1
  storage2
  storage3
```

```
$ knife node show storage1 -c /tmp/swiftknife.rb 
Node Name:   storage1
Environment: development
FQDN:        storage1
IP:          10.0.2.15
Run List:    recipe[apt], role[swift-setup], role[swift-management-server], role[swift-account-server], role[swift-object-server], role[swift-container-server], role[swift-proxy-server]
Roles:       swift-container-server, swift-object-server, swift-account-server, swift-proxy-server, swift-setup, swift-management-server
Recipes:     apt, swift::setup, swift::management-server, swift::account-server, swift::object-server, swift::container-server, swift::proxy-server
Platform:    ubuntu 12.04
Tags:        

```

