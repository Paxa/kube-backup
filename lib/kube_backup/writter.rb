require 'yaml'
require 'fileutils'
require 'socket'

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

    def get_changes
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
          return changes[:stdout]
        end
      end
    end

    def push_changes!(message, options)
      Dir.chdir(@target) do
        email = options[:git_email] || "kube-backup@#{Socket.gethostname}"
        name  = options[:git_name] || "kube-backup"

        run_cmd! %{git config user.email "#{email}"}
        run_cmd! %{git config user.name "#{name}"}

        run_cmd! %{git add .}
        run_cmd! %{git commit -m "#{message}"}

        res = run_cmd! %{git push origin master}

        KubeBackup.logger.error res[:stdout] if res[:stdout] != ''
        KubeBackup.logger.error res[:stderr] if res[:stderr] != ''
      end
    end

    def run_cmd!(command)
      res = KubeBackup.cmd(command)

      unless res[:success]
        KubeBackup.logger.error res[:stdout] if res[:stdout] != ''
        KubeBackup.logger.error res[:stderr] if res[:stderr] != ''
        raise res[:stderr] || "git command error"
      end

      res
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

    def write_raw(path, content)
      full_path = File.join(@target, path)
      full_path.gsub!(":", "_")

      dirname = File.dirname(full_path)

      if dirname != @target
        FileUtils.mkdir_p(dirname)
      end

      File.open(full_path, 'w') do |f|
        f.write(content)
      end
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