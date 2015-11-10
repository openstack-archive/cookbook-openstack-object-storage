#!/bin/bash -x
## This script is for installing all the needed packages on trusty to run the chef tests with 'chef exec rake'.
## It relies on the common bootstrap.sh from openstack/cookbook-openstack-common for installing common dependencies.

curl https://raw.githubusercontent.com/openstack/cookbook-openstack-common/stable/liberty/bootstrap.sh \
  --retry 3 \
  --silent \
  --show-error \
  | /bin/bash -x
