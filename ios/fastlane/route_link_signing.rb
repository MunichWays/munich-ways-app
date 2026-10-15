# Keep the App ID and generated distribution profile in sync with Runner's
# Associated Domains entitlement. Do not remove the entitlement to fix signing.
module RouteLinkSigning
  CAPABILITY = 'ASSOCIATED_DOMAINS'.freeze

  def self.ensure_capability(bundle_id)
    raise 'App ID com.munichways.app was not found in the configured Apple team.' unless bundle_id

    return false if bundle_id.get_capabilities.any? { |capability| capability.is_type?(CAPABILITY) }

    bundle_id.create_capability(CAPABILITY)
    true
  end
end
