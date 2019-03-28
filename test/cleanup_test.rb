require_relative 'test_helper'

describe "KubeBackup.clean_resource!" do
  it "should cleanup pod" do
    pod = load_sample(:single_pod)
    cleaned = load_sample(:single_pod)

    KubeBackup.clean_resource!(cleaned)

    assert_equal(pod.keys - cleaned.keys, ["status"])
    assert_equal(pod['spec'].keys - cleaned['spec'].keys, ["nodeName", "tolerations"])
  end
end
