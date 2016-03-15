# encoding: UTF-8
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

require 'chef/mixin/shell_out'
include Chef::Mixin::ShellOut

# rubocop:disable MethodLength
def load_current_resource
  dev_name = @new_resource.name
  @current = Chef::Resource::OpenstackObjectStorageDisk.new(dev_name)

  parted_partition_parse dev_name
  parts = @current.part

  unless @current.blocks
    # parted didn't return anything -- empty disk.
    # get size from sfdisk
    sfdisk_get_size(dev_name)
  end

  Chef::Log.info("About to print partition table for #{dev_name}")

  s = <<EOF
current state for dev #{dev_name}
  Size in 1K blocks: #{@current.blocks}
EOF

  Chef::Log.info("Printing partition table for #{dev_name}")

  num = 0
  parts.each do |p|
    s << 'partition ' << num
    s << " start/end/size (1k): #{p[:start]}/#{p[:end]}/#{p[:size]}"
    s << " type: #{p[:type]}"
    s << "\n"
    num += 1
  end unless parts.nil?
  Chef::Log.info(s)
end

# sample output
# sfdisk /dev/sdb -g
# /dev/sdb: 261 cylinders, 255 heads, 63 sectors/track
def sfdisk_get_size(dev_name)
  out = Mixlib::ShellOut.new("sfdisk #{dev_name} -s").run_command.stdout
  Chef::Log.info("size 1k blocks: #{out.to_i} for #{dev_name}")

  # sfdisk sees the world as 1k blocks
  @current.blocks(out.to_i)
end

def parted_partition_parse(dev_name)
  Chef::Log.info("reading partition table for #{dev_name}")

  # Run parted to get basic info about the disk
  # sample output:
  # # parted -m -s /dev/sda unit b print
  # BYT;
  # /dev/vda:8589934592B:virtblk:512:512:msdos:Virtio Block Device;
  # 1:1048576B:8589934591B:8588886016B:ext3::;
  pipe = IO.popen("parted -m -s #{dev_name} unit b print") # this can return 1, but it's ok (if no partition table present, we'll create it)
  result = pipe.readlines
  parted_parse_results result
end

def parted_parse_results(input)
  Chef::Log.debug('partition table: ' + input.inspect)
  input = input.to_a
  part_tab = []
  catch :parse_error do
    line = input.shift # Error or BYT;
    throw :parse_error if line =~ /^Error:/

    line = input.shift
    throw :parse_error unless line =~ %r{/dev/([^/]+):([0-9]+)B:(.*):.*$}

    blocks = Regexp.last_match(2).to_i / 1024

    if @current.blocks && @current.blocks != blocks
      throw "Our disk size changed.  Expecting: #{@current.blocks}, got #{blocks}"
    end

    @current.blocks(blocks)

    input.each do |input_line|
      # 1:1048576B:8589934591B:8588886016B:ext3::;

      throw :parse_error unless input_line =~ /([0-9]):([0-9]+)B:([0-9]+)B:([0-9]+)B:(.*):(.*):(.*);$/
      part_num = Regexp.last_match(1).to_i
      part_info = {
        num: part_num,
        start: Regexp.last_match(2).to_i / 1024,
        end: Regexp.last_match(3).to_i / 1024,
        size: Regexp.last_match(4).to_i / 1024,
        type: Regexp.last_match(5),
        system: Regexp.last_match(6),
        flags: Regexp.last_match(7)
      }
      part_tab << part_info
    end
  end

  @current.part(part_tab)
  part_tab
end

action :list do
  Chef::Log.info("at some point there'll be a list")
  new_resource.updated_by_last_action(update)
end

####
# compare the requested partition table parameters to what exists
# if differences found - remove all current partitions, and create new ones.
# An existing partition is considered a match if:
#  - it has the same serial # (1,2,3)
#  - it has the same size
#
# We also want to start to partition at 1M to be correctly aligned
# even due to 4K sector size and controller stripe sizes.
#
# Plus, then parted doesn't bitch every time you run it.

action :ensure_exists do
  Chef::Log.info('Entering :ensure_exists')

  req = @new_resource.part
  cur = @current.part
  dev_name = @new_resource.name
  update = false

  recreate = false

  disk_blocks = @current.blocks # 1k blocks

  if cur.nil?
    recreate = true
  else
    idx = 0
    current_block = 0

    Chef::Log.info("Checking partition #{idx} for #{dev_name}")

    req.each do |params|
      if cur[idx].nil?
        recreate = true
        Chef::Log.info("no current #{idx}")
        next
      end

      req_size = params[:size]   # size in Mb - convert to blocks
      if req_size == :remaining
        req_size = disk_blocks - current_block
      else
        req_size *= 1024
      end

      cur_size = cur[idx][:size]

      cur_min = req_size * 0.9
      cur_max = req_size * 1.1
      recreate = true unless (cur_size > cur_min) && (cur_size < cur_max)

      current_block += cur[idx][:size]
      Chef::Log.info("partition #{idx} #{(recreate ? 'differs' : 'is same')}: #{cur_size}/#{req_size} for #{dev_name}")
      idx += 1
    end
  end

  if !recreate
    Chef::Log.info('partition table matches for #{dev_name} - not recreating')
  else
    ### make sure to ensure that there are no mounted
    ### filesystems on the device
    re = /^(#{Regexp.escape(dev_name)}[0-9]+)/
    mounted = []
    shell_out!('mount').stdout.each_line do |line|
      md = re.match(line)
      next unless md
      mounted << md[1]
    end
    mounted.each do |m|
      Chef::Log.info("unmounting #{m} for #{dev_name}")
      shell_out!("umount #{m}")
    end

    # Nuke current partition table.
    Chef::Log.info("Creating partition table for #{dev_name}")
    cmd = Mixlib::ShellOut.new("parted -s -m #{dev_name} mktable gpt").run_command
    Chef::Log.info("Created partition table for #{dev_name} out:#{cmd.stdout.strip} err:#{cmd.stderr.strip}")

    # create new partitions
    idx = 0
    req.each do |params|
      start_block = 0

      start_block = '1M' if idx == 0

      if params[:size] == :remaining
        requested_size = '100%'
      else
        requested_size = "#{params[:size]}M"
      end

      Chef::Log.info("Creating partition #{idx + 1} for #{dev_name}")
      cmd = Mixlib::ShellOut.new("parted -m -s #{dev_name} mkpart #{idx} #{start_block} #{requested_size}").run_command
      Chef::Log.info("Created partition #{idx + 1} for #{dev_name} out:#{cmd.stdout.strip} err:#{cmd.stderr.strip}")

      idx += 1
    end
    update = true
  end

  # walk through the partitions and enforce disk format
  idx = 1
  req.each do |params|
    device = "#{dev_name}#{idx}"
    Chef::Log.info("Testing file system on #{device} for type #{params[:type]}")

    case params[:type]
    when 'xfs'
      if Mixlib::ShellOut.new("xfs_admin -l #{device}").run_command.error?
        Chef::Log.info("Creating file system on #{device} for type #{params[:type]}")
        cmd = Mixlib::ShellOut.new("mkfs.xfs -L swift -f -i size=512 #{device}").run_command
        Chef::Log.info("Created file system on #{device} for type #{params[:type]} out:#{cmd.stdout.strip} err:#{cmd.stderr.strip}")
        update = true
      end
    when 'ext4'
      unless Mixlib::ShellOut.new("tune2fs -l #{device} | awk \'/Filesystem volume name:/{print $4}\' | grep -v \"<none>\"").run_command.error?
        Chef::Log.info("Creating file system on #{device} for type #{params[:type]}")
        cmd = Mixlib::ShellOut.new("mkfs.ext4 -L swift #{device}").run_command
        Chef::Log.info("Created file system on #{device} for type #{params[:type]} out:#{cmd.stdout.strip} err:#{cmd.stderr.strip}")
        update = true
      end
    end
  end
  new_resource.updated_by_last_action(update)
end
