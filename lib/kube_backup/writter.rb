require 'yaml'
require 'fileutils'

module KubeBackup
  class Writter
    def initialize(target, git_url)
      @target = target
      @git_url = git_url
    end

    def init_repo!
      clone_repo!
      remove_repo_content!
    end

    def has_changes?
      Dir.chdir(@target) do
        changes = KubeBackup.cmd(%{git status --porcelain})

        unless changes[:success]
          KubeBackup.logger.error changes[:stderr]
          raise changes[:stderr] || "git clone error"
        end

        if changes[:stdout] == ''
          KubeBackup.logger.info "No changes"
          return false
        else
          puts changes[:stdout]
          return true
        end
      end
    end

    def push_changes!(message)
      Dir.chdir(@target) do
        res = KubeBackup.cmd(%{git add .})

        unless res[:success]
          KubeBackup.logger.error res[:stdout] if res[:stdout] != ''
          KubeBackup.logger.error res[:stderr] if res[:stderr] != ''
          raise res[:stderr] || "git commit error"
        end

        res = KubeBackup.cmd(%{git commit -m "#{message}"})

        unless res[:success]
          KubeBackup.logger.error res[:stdout] if res[:stdout] != ''
          KubeBackup.logger.error res[:stderr] if res[:stderr] != ''
          raise res[:stderr] || "git commit error"
        end

        res = KubeBackup.cmd(%{git push origin master})

        unless res[:success]
          KubeBackup.logger.error res[:stdout] if res[:stdout] != ''
          KubeBackup.logger.error res[:stderr] if res[:stderr] != ''
          raise res[:stderr] || "git push error"
        end

        KubeBackup.logger.info res[:stdout]
      end
    end

    def print_changed_files
      Dir.chdir(@target) do
        res = KubeBackup.cmd(%{git status --porcelain})
        if res[:stdout] == ''
          KubeBackup.logger.info "No changes"
        else
          KubeBackup.logger.info "Changes:\n#{res[:stdout]}"
        end
      end
    end

    def write_res(resource)
      type = resource["kind"]
      write_yaml("_global_/#{type}/#{resource["metadata"]["name"]}.yaml", resource)
    end

    def write_ns_res(resource)
      ns = resource["metadata"]["namespace"]
      type = resource["kind"] #gsub(/(.)([A-Z])/,'\1_\2').downcase

      write_yaml("#{ns}/#{type}/#{resource["metadata"]["name"]}.yaml", resource)
    end

    def write_yaml(path, data)
      full_path = File.join(@target, path)
      full_path.gsub!(":", "_")

      dirname = File.dirname(full_path)

      if dirname != @target
        FileUtils.mkdir_p(dirname)
      end

      File.open(full_path, 'w') do |f|
        f.write(YAML.dump(data))
      end
    end

    def remove_repo_content!
      objects = Dir.entries(@target).map do |object|
        if object.start_with?(".")
          nil
        else
          File.join(@target, object)
        end
      end.compact

      FileUtils.rm_r(objects, verbose: false)
    end

    def clone_repo!
      res = KubeBackup.cmd(%{git clone --depth 10 "#{@git_url}" "#{@target}"})
      unless res[:success]
        KubeBackup.logger.error res[:stderr]
        raise res[:stderr] || "git clone error"
      end
    end
  end
end