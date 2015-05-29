# encoding: UTF-8
require 'chefspec'
require 'chefspec/berkshelf'
require 'chef/application'

ChefSpec::Coverage.start! { add_filter 'openstack-compute' }

LOG_LEVEL = :fatal
REDHAT_OPTS = {
  platform: 'redhat',
  version: '7.1',
  log_level: LOG_LEVEL
}
UBUNTU_OPTS = {
  platform: 'ubuntu',
  version: '14.04',
  log_level: LOG_LEVEL
}
SUSE_OPTS = {
  platform: 'suse',
  version: '11.3',
  log_level: LOG_LEVEL
}

MOCK_NODE_NETWORK_DATA =
  {
    'ipaddress' => '10.0.0.2',
    'fqdn' => 'localhost.localdomain',
    'hostname' => 'localhost',
    'network' => {
      'default_interface' => 'eth0',
      'interfaces' => {
        'eth0' => {
          'addresses' => {
            'fe80::a00:27ff:feca:ab08' => { 'scope' => 'Link', 'prefixlen' => '64', 'family' => 'inet6' },
            '10.0.0.2' => { 'netmask' => '255.255.255.0', 'broadcast' => '10.0.0.255', 'family' => 'inet' },
            '08:00:27:CA:AB:08' => { 'family' => 'lladdr' }
          }
        },
        'lo' => {
          'addresses' => {
            '::1' => { 'scope' => 'Node', 'prefixlen' => '128', 'family' => 'inet6' },
            '127.0.0.1' => { 'netmask' => '255.0.0.0', 'family' => 'inet' }
          }
        }
      }
    }
  }

shared_context 'swift-stubs' do
  before do
    stub_command('/usr/bin/id swift').and_return(true)
    stub_command('[ -x /etc/swift/pull-rings.sh ]').and_return(true)
    stub_command('[ -f /etc/rsyncd.conf ]').and_return(true)
    stub_command("grep -q 'RSYNC_ENABLE=false' /etc/default/rsync").and_return(true)
    stub_command('[ -e /etc/swift/account-server.conf ] && [ -e /etc/swift/account.ring.gz ]').and_return(true)
    stub_command('[ -e /etc/swift/container-server.conf ] && [ -e /etc/swift/container.ring.gz ]').and_return(true)
    stub_command('[ -e /etc/init/swift-container-sync.conf ]').and_return(false)
    stub_command('[ -e /etc/init.d/swift-container-sync ]').and_return(false)
    stub_command('[ -e /etc/swift/object-server.conf ] && [ -e /etc/swift/object.ring.gz ]').and_return(true)
    stub_command('[ -e /etc/swift/proxy-server.conf ] && [ -e /etc/swift/object.ring.gz ]').and_return(true)

    # create mock cluster
    n = Chef::Node.new
    n.name('manager')
    n.default_attrs = {
      'swift' => {
        'service_pass' => 'foobar'
      }
    }
    allow_any_instance_of(Chef::Recipe).to receive(:search).with(:node, 'chef_environment:_default AND roles:os-object-storage-setup').and_return([n])
    allow(Chef::Application).to receive(:fatal!)

    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('token', 'openstack_identity_bootstrap_token')
      .and_return('bootstrap-token')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('service', 'openstack-object-storage')
      .and_return('swift-pass')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('token', 'swift_hash_path_prefix')
      .and_return('swift_hash_path_prefix-secret')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('token', 'swift_hash_path_suffix')
      .and_return('swift_hash_path_suffix-secret')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('token', 'swift_authkey')
      .and_return('swift_authkey-secret')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('token', 'dispersion_auth_user')
      .and_return('dispersion_auth_user-secret')
    allow_any_instance_of(Chef::Recipe).to receive(:get_password)
      .with('token', 'dispersion_auth_key')
      .and_return('dispersion_auth_key-secret')
    allow_any_instance_of(Chef::Recipe).to receive(:memcached_servers)
      .and_return(['host1:111', 'host2:222'])
  end
end

shared_examples 'keystone-authmode' do
  describe 'authorization mode' do
    it 'does upgrade keystoneclient package' do
      expect(chef_run).to upgrade_package('python-keystoneclient')
    end
  end
end

shared_examples 'a common swift server configurator' do |server_type, bind_ip, bind_port|
  { 'bind_ip' => "#{bind_ip}",
    'bind_port' => "#{bind_port}",
    'log_statsd_default_sample_rate' => '1',
    'log_statsd_metric_prefix' => 'openstack.swift.Fauxhai',
    'max_clients' => '1024',
    'workers' => 'auto' }.each do |k, v|
    it "sets the default for #{k}" do
      expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^#{Regexp.quote("#{k} = #{v}")}$/)
    end
  end

  %w(ip port).each do |attr|
    it "sets the bind_#{attr} attr" do
      node.set['openstack']['object-storage']['network']["#{server_type}-bind-#{attr}"] = "#{attr}_value"
      expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^bind_#{attr} = #{attr}_value$/)
    end
  end

  context 'statistics enabled' do
    before do
      node.set['openstack']['object-storage']['statistics']['enabled'] = true
    end

    it 'sets the log_statsd_default_sample_rate attribute' do
      node.set['openstack']['object-storage']['statistics']['sample_rate'] = 'sample_rate_value'
      expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^log_statsd_default_sample_rate = sample_rate_value$/)
    end

    it 'sets the log_statsd_metric_prefix attribute' do
      node.set['openstack']['object-storage']['statistics']['statsd_prefix'] = 'statsd_prefix_value'
      chef_run.node.automatic['hostname'] = 'myhostname'
      expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^log_statsd_metric_prefix = statsd_prefix_value\.myhostname$/)
    end
  end

  it 'does not show statistic related attributed when disabled' do
    node.set['openstack']['object-storage']['statistics']['enabled'] = false
    expect(chef_run).not_to render_config_file(file.name).with_section_content('DEFAULT', /^log_statsd_host = localhost$/)
  end
end

shared_examples 'a common swift server default attribute values checker' do |server_type, bind_ip, bind_port|
  it 'bind_ip' do
    expect(chef_run.node['openstack']['object-storage']['network']["#{server_type}-bind-ip"]).to eq(bind_ip)
  end

  it 'bind_port' do
    expect(chef_run.node['openstack']['object-storage']['network']["#{server_type}-bind-port"]).to eq(bind_port)
  end

  it 'log_statsd_default_sample_rate' do
    expect(chef_run.node['openstack']['object-storage']['statistics']['sample_rate']).to eq(1)
  end

  it 'statsd_prefix' do
    expect(chef_run.node['openstack']['object-storage']['statistics']['statsd_prefix']).to eq('openstack.swift')
  end

  it 'hostname' do
    expect(chef_run.node['hostname']).to eq('Fauxhai')
  end

  it 'workers' do
    expect(chef_run.node['openstack']['object-storage']["#{server_type}-server"]['workers']).to eq('auto')
  end
end

shared_examples 'custom template banner displayer' do
  it 'shows the custom banner' do
    node.set['openstack']['object-storage']['custom_template_banner'] = 'custom_template_banner_value'
    expect(chef_run).to render_file(file_name).with_content(/^custom_template_banner_value$/)
  end
end

shared_examples 'some common swift server values' do
  { 'devices' => '/srv/node',
    'mount_check' => 'true' }.each do |k, v|
    it "sets the default for #{k}" do
      expect(chef_run).to render_config_file(file.name).with_section_content('DEFAULT', /^#{Regexp.quote("#{k} = #{v}")}$/)
    end
  end
end
