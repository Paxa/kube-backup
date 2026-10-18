require_relative 'test_helper'

describe "KubeBackup.parse_regex" do
  it "returns nil for nil or empty string" do
    assert_nil KubeBackup.parse_regex(nil)
    assert_nil KubeBackup.parse_regex("")
    assert_nil KubeBackup.parse_regex("   ")
  end

  it "parses regex with leading and trailing slashes" do
    rx = KubeBackup.parse_regex("/^gitlab-runner-\\d+$/")
    assert_instance_of Regexp, rx
    assert rx.match?("gitlab-runner-1234")
    refute rx.match?("production")
  end

  it "parses regex with trailing flags" do
    rx = KubeBackup.parse_regex("/^test-\\d+$/i")
    assert_instance_of Regexp, rx
    assert rx.match?("TEST-42")
    refute rx.match?("other")
  end

  it "parses plain regex string without slashes" do
    rx = KubeBackup.parse_regex("^gitlab-runner-\\d+$")
    assert_instance_of Regexp, rx
    assert rx.match?("gitlab-runner-999")
    refute rx.match?("staging")
  end

  it "passes through Regexp instances" do
    original = /^custom-.*/
    assert_equal original, KubeBackup.parse_regex(original)
  end

  it "handles invalid regex gracefully without crashing" do
    assert_nil KubeBackup.parse_regex("(")
  end
end
