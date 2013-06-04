#!/bin/bash 
set -x
set -e

# define static IPs for our cluster
export CHEFSERVER=10.0.0.2
export STORAGE1=10.0.0.10
export STORAGE2=10.0.0.11
export STORAGE3=10.0.0.12
export DISK_DIR=/tmp/swift-disks
export DISK_SIZE=15360
export SWAUTH_KEY=test


attach_storage_disks() {

  HOST=$1
  MADE_CONTROLLER=0

  mkdir -p ${DISK_DIR}
  
    for d in 1 2 3 4 5; do
      imgfile="${DISK_DIR}/${HOST}${s}-${d}.vdi"
      if [ ! -f $imgfile ]; then
        if [ $MADE_CONTROLLER -eq 0 ];
        then
            VBoxManage storagectl ${HOST} --name "SAS Controller" --add sas --controller LSILogicSAS
            MADE_CONTROLLER=1
        fi;
        echo "[+] Creating disk $imgfile"
        VBoxManage createhd --filename $imgfile --size $DISK_SIZE --format VDI --variant Standard
        VBoxManage storageattach ${HOST} --storagectl "SAS Controller" --port ${d} --device 0 --type hdd --medium $imgfile
      fi
    done

}

clean_environment() {

    # install cookbooks
    rm -rf /tmp/swiftbooks

    # ensure any existing copies of storage1-3 and chefserver are removed
    vagrant destroy storage1 -f
    vagrant destroy storage2 -f
    vagrant destroy storage3 -f
    vagrant destroy chefserver -f
    rm -rf /tmp/swift-disks

}

berks_install() {

    berks install --path=/tmp/swiftbooks

}

chefserver_create() {

    # create chefserver
    vagrant up chefserver

    # create basic knife access on localhost
    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${1} "sudo /opt/vagrant_ruby/bin/knife configure -i --defaults -y -r ''"
    
    # extract validation key for chef clients
    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${1} "sudo cat /etc/chef/validation.pem" > /tmp/swift-validation.pem
    
    # create workstation knife client and extract key
    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${1} "sudo /opt/vagrant_ruby/bin/knife client create knifeclient -d -a -f /tmp/knifeclient.pem"
    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${1} "cat /tmp/knifeclient.pem" > /tmp/knifeclient.pem
    
# create workstation knife configuration
cat <<EOF>/tmp/swiftknife.rb
log_level                :info
log_location             STDOUT
node_name                'knifeclient'
client_key               '/tmp/knifeclient.pem'
validation_client_name   'chef-validator'
validation_key           '/etc/chef/validation.pem'
chef_server_url          'http://${1}:4000'
cache_type               'BasicFile'
cache_options( :path => '/tmp/chef-checksums' )

EOF

}

chefserver_load() {

    # load chef up
    knife environment from file tests/environments/development.json -c /tmp/swiftknife.rb
    knife role from file tests/roles/*.json -c /tmp/swiftknife.rb
    knife node from file tests/data_bags/node/storage1.json -c /tmp/swiftknife.rb
    knife node from file tests/data_bags/node/storage2.json -c /tmp/swiftknife.rb
    knife node from file tests/data_bags/node/storage3.json -c /tmp/swiftknife.rb
    knife cookbook upload -d -a --cookbook-path=/tmp/swiftbooks -c /tmp/swiftknife.rb

}


chefserver_reload() {

  knife cookbook upload -a -d --cookbook-path=/tmp/swiftbooks -c /tmp/swiftknife.rb 

}

storage_create() {

    # create initial storage server, and attach disks
    sleep 5; vagrant up $1
    sleep 5; vagrant halt $1
    sleep 5; attach_storage_disks $1
    sleep 5; vagrant up $1
}

storage_chefrun() {

    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${1} "cd /tmp/vagrant* && sudo /opt/vagrant_ruby/bin/chef-client -j dna.json -c ./client.rb"

}

storage_ring_init() {

    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${STORAGE1} "sudo /etc/swift/ring-workspace/generate-rings.sh --force"
    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${STORAGE1} "sudo sh -c \"cd /etc/swift/ring-workspace/rings; git add -A; git commit -m initial_rings; git push\""
 
    storage_chefrun ${STORAGE2}
    storage_chefrun ${STORAGE3}
    storage_chefrun ${STORAGE1}

}

swauth_setup() {

    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${1} "swauth-prep -K ${SWAUTH_KEY}"
    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${1} "swauth-add-account -K ${SWAUTH_KEY} test"
    ssh -o StrictHostKeyChecking=no -i ~/.vagrant.d/insecure_private_key vagrant@${1} "swauth-add-user -a -K ${SWAUTH_KEY} test test test"

}


case "$1" in


   clean)

    clean_environment

   ;;

   run)
 
    clean_environment
    berks_install

    chefserver_create $CHEFSERVER
    chefserver_load

    # create storage1 and do several chefruns
    storage_create storage1
    storage_chefrun $STORAGE1
    storage_chefrun $STORAGE1
    storage_chefrun $STORAGE1
    storage_chefrun $STORAGE1

    # create storage2 and do several chefruns
    storage_create storage2
    storage_chefrun $STORAGE2
    storage_chefrun $STORAGE2
    storage_chefrun $STORAGE2
    storage_chefrun $STORAGE2

    # create storage3 and do several chefruns
    storage_create storage3
    storage_chefrun $STORAGE3
    storage_chefrun $STORAGE3
    storage_chefrun $STORAGE3
    storage_chefrun $STORAGE3

    # let storage1 rebuild now that 2 and 3 
    # have reported their devices to the
    # chefserver - this will modify
    # generate-rings.sh
    storage_chefrun $STORAGE1

    # lets call generate-rings with --force and
    # then manually push the ring to git so
    # the other storage servers pick it up
    storage_ring_init

    # prep swauth and create test user
    swauth_setup $STORAGE1

  ;;

  refresh_clients)

    berks_install
    chefserver_reload 
    storage_chefrun $STORAGE1
    storage_chefrun $STORAGE2
    storage_chefrun $STORAGE3

  ;;

  rerun_clients)

    storage_chefrun $STORAGE1
    storage_chefrun $STORAGE2
    storage_chefrun $STORAGE3

  ;;

  reload_chef)

    berks_install
    chefserver_reload 

  ;;

  init_chef)

    chefserver_load

  ;;

  *)

    echo "Usage: $0 (clean|run|refresh_clients|reload_chef)"
    exit 1

  ;;

esac

