# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::identity_registration' do
  let(:runner) { ChefSpec::SoloRunner.new(UBUNTU_OPTS) }
  let(:node) { runner.node }
  let(:chef_run) do
    runner.converge(described_recipe)
  end

  include_context 'swift-stubs'

  it 'registers object storage service' do
    expect(chef_run).to create_service_openstack_identity_register(
      'Register Object Storage Service'
    ).with(
      auth_uri: 'http://127.0.0.1:35357/v2.0',
      bootstrap_token: 'bootstrap-token',
      service_type: 'object-store',
      service_description: 'Swift Service',
      action: [:create_service]
    )
  end

  context 'registers object storage endpoint' do
    it 'with default values' do
      expect(chef_run).to create_endpoint_openstack_identity_register(
        'Register Object Storage Endpoint'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        service_type: 'object-store',
        endpoint_region: 'RegionOne',
        endpoint_adminurl: 'http://127.0.0.1:8080/v1/AUTH_%(tenant_id)s',
        endpoint_internalurl: 'http://127.0.0.1:8080/v1/AUTH_%(tenant_id)s',
        endpoint_publicurl: 'http://127.0.0.1:8080/v1/AUTH_%(tenant_id)s',
        action: [:create_endpoint]
      )
    end

    it 'with different admin URL ' do
      general_url = 'http://general.host:456/general_path'
      admin_url = 'https://admin.host:123/admin_path'

      # Set general endpoint
      node.set['openstack']['endpoints']['object-storage-api']['uri'] = general_url
      # Set the admin endpoint override
      node.set['openstack']['endpoints']['admin']['object-storage-api']['uri'] = admin_url

      expect(chef_run).to create_endpoint_openstack_identity_register(
        'Register Object Storage Endpoint'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        service_type: 'object-store',
        endpoint_region: 'RegionOne',
        endpoint_adminurl: admin_url,
        endpoint_internalurl: general_url,
        endpoint_publicurl: general_url,
        action: [:create_endpoint]
      )
    end

    it 'with different internal URL ' do
      general_url = 'http://general.host:456/general_path'
      internal_url = 'http://internal.host:456/internal_path'

      # Set general endpoint
      node.set['openstack']['endpoints']['object-storage-api']['uri'] = general_url
      # Set the internal endpoint override
      node.set['openstack']['endpoints']['internal']['object-storage-api']['uri'] = internal_url

      expect(chef_run).to create_endpoint_openstack_identity_register(
        'Register Object Storage Endpoint'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        service_type: 'object-store',
        endpoint_region: 'RegionOne',
        endpoint_adminurl: general_url,
        endpoint_internalurl: internal_url,
        endpoint_publicurl: general_url,
        action: [:create_endpoint]
      )
    end

    it 'with different public URL ' do
      general_url = 'http://general.host:456/general_path'
      public_url = 'https://public.host:789/public_path'

      # Set general endpoint
      node.set['openstack']['endpoints']['object-storage-api']['uri'] = general_url
      # Set the public endpoint override
      node.set['openstack']['endpoints']['public']['object-storage-api']['uri'] = public_url

      expect(chef_run).to create_endpoint_openstack_identity_register(
        'Register Object Storage Endpoint'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        service_type: 'object-store',
        endpoint_region: 'RegionOne',
        endpoint_adminurl: general_url,
        endpoint_internalurl: general_url,
        endpoint_publicurl: public_url,
        action: [:create_endpoint]
      )
    end

    it 'with all different URLs ' do
      admin_url = 'https://admin.host:123/admin_path'
      internal_url = 'http://internal.host:456/internal_path'
      public_url = 'https://public.host:789/public_path'

      node.set['openstack']['endpoints']['admin']['object-storage-api']['uri'] = admin_url
      node.set['openstack']['endpoints']['internal']['object-storage-api']['uri'] = internal_url
      node.set['openstack']['endpoints']['public']['object-storage-api']['uri'] = public_url
      expect(chef_run).to create_endpoint_openstack_identity_register(
        'Register Object Storage Endpoint'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        service_type: 'object-store',
        endpoint_region: 'RegionOne',
        endpoint_adminurl: admin_url,
        endpoint_internalurl: internal_url,
        endpoint_publicurl: public_url,
        action: [:create_endpoint]
      )
    end

    it 'with custom region override' do
      node.set['openstack']['object-storage']['region'] = 'swiftRegion'
      expect(chef_run).to create_endpoint_openstack_identity_register(
        'Register Object Storage Endpoint'
      ).with(
        auth_uri: 'http://127.0.0.1:35357/v2.0',
        bootstrap_token: 'bootstrap-token',
        service_type: 'object-store',
        endpoint_region: 'swiftRegion',
        endpoint_adminurl: 'http://127.0.0.1:8080/v1/AUTH_%(tenant_id)s',
        endpoint_internalurl: 'http://127.0.0.1:8080/v1/AUTH_%(tenant_id)s',
        endpoint_publicurl: 'http://127.0.0.1:8080/v1/AUTH_%(tenant_id)s',
        action: [:create_endpoint]
      )
    end
  end

  it 'registers service tenant' do
    expect(chef_run).to create_tenant_openstack_identity_register(
      'Register Service Tenant'
    ).with(
      auth_uri: 'http://127.0.0.1:35357/v2.0',
      bootstrap_token: 'bootstrap-token',
      tenant_name: 'service',
      tenant_description: 'Service Tenant',
      action: [:create_tenant]
    )
  end

  it 'registers service user' do
    expect(chef_run).to create_user_openstack_identity_register(
      'Register swift User'
    ).with(
      auth_uri: 'http://127.0.0.1:35357/v2.0',
      bootstrap_token: 'bootstrap-token',
      tenant_name: 'service',
      user_name: 'swift',
      user_pass: 'swift-pass',
      action: [:create_user]
    )
  end

  it 'grants service role to service user for service tenant' do
    expect(chef_run).to grant_role_openstack_identity_register(
      "Grant 'service' Role to swift User for service Tenant"
    ).with(
      auth_uri: 'http://127.0.0.1:35357/v2.0',
      bootstrap_token: 'bootstrap-token',
      tenant_name: 'service',
      role_name: 'service',
      user_name: 'swift',
      action: [:grant_role]
    )
  end
end
