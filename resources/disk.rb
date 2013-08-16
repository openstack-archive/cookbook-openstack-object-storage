#
# Copyright 2011, Dell
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: andi abes
#

=begin
  Ensure that a disk's partition table matches expectations.
  Sample use:

  openstack_object_storage_disk "/dev/sdb" do
    part(
       {[:type => "xfs", :size =>swift_disk::ONE_GIG*4 ],
        [:type => "xfs", :size =>swift_disk::remaining})
     action :ensure_exists
  end

=end

actions :ensure_exists

def initialize(*args)
  super
  @action = :ensure_exists
end

attribute :name,   :kind_of => String
attribute :size,   :kind_of => Integer
attribute :blocks, :kind_of => Integer
attribute :device, :kind_of => String
attribute :part,   :kind_of => Array
attribute :status, :kind_of => Symbol
