require_relative 'test_helper'

describe "KubeBackup.sort_keys!" do
  it "should sort keys in configmap" do
    config_map = load_sample(:config_map)

    config_map = KubeBackup.sort_keys!(config_map)

    assert_equal(config_map.keys, ["apiVersion", "kind", "metadata", "data"])
  end
end
