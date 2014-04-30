# CHANGELOG for cookbook-openstack-object-storage

This file is used to list changes made in each version of cookbook-openstack-object-storage.
## 9.0.2
* Fix package action to allow updates

## 9.0.1
* Fix package reference, need keystone client not keystone

## 9.0.0
* Upgrade to Icehouse

## 8.3.0:
* Rename all attributes to conform to other cookbooks.
* bugfix in mount lwrp that broke deployment.

## 8.2.0:
* Add support for several swift modules:
  domain_remap, formpost

## 8.1.0
* Add client recipe

## 8.0.1
* Bugfix ring_script.rb to handle recent swift-ring-builder
  output with replication information

## 8.0.0
### New version
* Upgrade to upstream Havana release

## 7.1.0:
* Update apt sources to grizzly to prepare for grizzly
  and havana branches

## 7.0.11:
* Add missing swift-container-sync upstart service which is
  not setup by default in ubuntu 12.04 packages

## 7.0.10:
* Do not role restrict super_admin_key in proxy config
* Case correct swauth_version attribute in proxy recipe
* Treat platform_options["swauth_packages"] as a list

## 7.0.9:
* Bugfix tempurl role restriction

## 7.0.8:
* Bugfix allow_override spacing in proxy server template

## 7.0.7:
* Add flexibility to middleware pipeline

## 7.0.6:
* Add choice of install python-swauth from git or package

## 7.0.5:
* Add support for container-sync

## 7.0.4:
* Allow roles used in searches to be defined by cookbook user

## 7.0.3:
* Bugfix the swift-ring-builder output scanner

## 7.0.2:
* Expand statsd support as well as capacity and recon supporting.

## 7.0.1:
* Support more then 24 disks (/dev/sdaa, /dev/vdab, etc)

## 7.0.0:
* Initial openstack object storage cookbook
