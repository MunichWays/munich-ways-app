require 'minitest/autorun'
require_relative '../route_link_signing'

class RouteLinkSigningTest < Minitest::Test
  Capability = Struct.new(:type) do
    def is_type?(expected)
      type == expected
    end
  end

  class BundleId
    attr_reader :created

    def initialize(types)
      @capabilities = types.map { |type| Capability.new(type) }
      @created = []
    end

    def get_capabilities
      @capabilities
    end

    def create_capability(type)
      @created << type
      @capabilities << Capability.new(type)
    end
  end

  def test_missing_capability_is_enabled_without_changing_existing_capabilities
    bundle = BundleId.new(['PUSH_NOTIFICATIONS'])
    assert RouteLinkSigning.ensure_capability(bundle)
    assert_equal ['ASSOCIATED_DOMAINS'], bundle.created
    assert bundle.get_capabilities.any? { |capability| capability.is_type?('PUSH_NOTIFICATIONS') }
  end

  def test_repeated_runs_do_not_recreate_capability
    bundle = BundleId.new(['ASSOCIATED_DOMAINS'])
    refute RouteLinkSigning.ensure_capability(bundle)
    assert_empty bundle.created
  end

  def test_missing_identifier_and_apple_errors_are_not_ignored
    assert_raises(RuntimeError) { RouteLinkSigning.ensure_capability(nil) }
    bundle = BundleId.new([])
    def bundle.create_capability(_type)
      raise 'Apple API access denied'
    end
    error = assert_raises(RuntimeError) { RouteLinkSigning.ensure_capability(bundle) }
    assert_match(/access denied/, error.message)
  end
end
