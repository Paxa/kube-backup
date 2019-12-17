require_relative 'test_helper'

describe "KubeBackup.clean_resource!" do
  it "should cleanup pod" do
    pod = load_sample(:single_pod)
    cleaned = load_sample(:single_pod)

    KubeBackup.clean_resource!(cleaned)

    assert_equal(pod.keys - cleaned.keys, ["status"])
    assert_equal(pod['spec'].keys - cleaned['spec'].keys, [
      "dnsPolicy", "nodeName", "restartPolicy", "schedulerName",
      "securityContext", "terminationGracePeriodSeconds", "tolerations"
    ])
    assert_equal(pod['spec']['containers'][0].keys - cleaned['spec']['containers'][0].keys, [
      "terminationMessagePath", "terminationMessagePolicy"
    ])
  end

  it "should cleanup deployment" do
    deploy = load_sample(:deployment)
    cleaned = load_sample(:deployment)

    KubeBackup.clean_resource!(cleaned)

    assert_equal(deploy.keys - cleaned.keys, ["status"])
    assert_equal(deploy['spec'].keys - cleaned['spec'].keys, ["progressDeadlineSeconds"])
    assert_equal(deploy['spec'].keys - cleaned['spec'].keys, ["progressDeadlineSeconds"])
    assert_equal(deploy['spec']['template']['spec'].keys - cleaned['spec']['template']['spec'].keys, [
      "dnsPolicy", "restartPolicy", "schedulerName",
      "securityContext", "terminationGracePeriodSeconds"
    ])
  end
end
