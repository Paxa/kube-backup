require_relative 'test_helper'
require 'tmpdir'

describe "KubeBackup::Writter" do
  describe "#remove_repo_content!" do
    it "should remove files in root target directory while keeping dotfiles" do
      Dir.mktmpdir do |dir|
        File.write(File.join(dir, "deployment.yaml"), "kind: Deployment")
        File.write(File.join(dir, ".gitkeep"), "")

        writter = KubeBackup::Writter.new(target_path: dir)
        writter.remove_repo_content!

        refute File.exist?(File.join(dir, "deployment.yaml"))
        assert File.exist?(File.join(dir, ".gitkeep"))
      end
    end

    it "should remove files when git_prefix is specified without error" do
      Dir.mktmpdir do |dir|
        prefix = "clusters/prod"
        FileUtils.mkdir_p(File.join(dir, prefix))
        File.write(File.join(dir, prefix, "service.yaml"), "kind: Service")
        File.write(File.join(dir, prefix, ".gitkeep"), "")

        writter = KubeBackup::Writter.new(target_path: dir, git_prefix: prefix)
        writter.remove_repo_content!

        refute File.exist?(File.join(dir, prefix, "service.yaml"))
        assert File.exist?(File.join(dir, prefix, ".gitkeep"))
      end
    end
  end
end
