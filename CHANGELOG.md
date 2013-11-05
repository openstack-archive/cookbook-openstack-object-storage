# CHANGELOG for cookbook-openstack-object-storage

This file is used to list changes made in each version of cookbook-openstack-object-storage.

## 7.0.10:
* Do not role restrict super_admin_key in proxy config and
  case correct swauth_version attribute in proxy recipe

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
