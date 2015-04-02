# encoding: UTF-8
#
# Cookbook Name:: openstack-object-storage
# Library:: service_utils
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

# Service Related Utilities
module ServiceUtils
  # Build platform specific service name
  def svc_name(service_name)
    platform_options = node['openstack']['object-storage']['platform']
    platform_options['service_prefix'] + service_name + platform_options['service_suffix']
  end
end
