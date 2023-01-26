require 'shellwords'
require 'yaml'
require 'fileutils'
require 'socket'

module KubeBackup
  class Writter
    def initialize(options = {})
      @options = options
      @target = options[:target_path]
      @git_url = options[:repo_url]
      @git_branch = options[:git_branch] || 'master'
      @git_prefix = options[:git_prefix] || '.'
    end

    def init_repo!
      clone_repo!
      remove_repo_content!
    end

    def get_changes
      Dir.chdir(File.join(@target, @git_prefix)) do
        changes = KubeBackup.cmd(%{git status --porcelain "#{@git_prefix}" --untracked-files=all})

        unless changes[:success]
          KubeBackup.logger.error changes[:stderr]
          raise changes[:stderr] || "git status error"
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

    def push_changes!(message)
      Dir.chdir(@target) do
        email = @options[:git_email] || "kube-backup@#{Socket.gethostname}"
        name  = @options[:git_name] || "kube-backup"

        run_cmd! %{git config user.email "#{email}"}
        run_cmd! %{git config user.name "#{name}"}

        run_cmd! %{git add "#{@git_prefix}" --all}
        run_cmd! %{git commit -m "#{message}"}

        res = run_cmd! %{git push origin "#{@git_branch}"}

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
        res = KubeBackup.cmd(%{git status --porcelain "#{@git_prefix}"})
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
      full_path = File.join(@target, @git_prefix, path)
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
      full_path = File.join(@target, @git_prefix, path)
      full_path.gsub!(":", "_")

      dirname = File.dirname(full_path)

      if dirname != @target
        FileUtils.mkdir_p(dirname)
      end

      File.open(full_path, 'w') do |f|
        f.write(YAML.dump(data))
      end
    end

    def restore(path)
      full_path = File.join(@git_prefix, path)

      Dir.chdir(@target) do
        res = KubeBackup.cmd(%{git checkout -f HEAD -- #{Shellwords.escape(full_path)}})
        if res[:success]
          KubeBackup.logger.info "Restored #{full_path} from HEAD"
        else
          KubeBackup.logger.error res[:stderr]
          raise res[:stderr] || "git reset error"
        end
      end
    end

    def remove_repo_content!
      objects = Dir.entries(File.join(@target, @git_prefix)).map do |object|
        if object.start_with?(".")
          nil
        else
          File.join(@target, @git_prefix, object)
        end
      end.compact

      FileUtils.rm_r(objects, verbose: false)
    end

    def clone_repo!
      check_known_hosts!

      res = KubeBackup.cmd(%{git clone -b "#{@git_branch}" --depth 10 "#{@git_url}" "#{@target}"})
      FileUtils.mkdir_p(File.join(@target, @git_prefix))

      unless res[:success]
        KubeBackup.logger.error(res[:stderr])
        if res[:stderr] =~ /Remote branch #{@git_branch} not found in upstream origin/
          Dir.chdir(@target) do
            KubeBackup.logger.info("Init new repo..")
            cmd_res = KubeBackup.cmd(%{git init .})
            KubeBackup.logger.error(res[:stderr]) unless cmd_res[:success]
            cmd_res = KubeBackup.cmd(%{git remote add origin "#{@git_url}"})
            KubeBackup.logger.error(res[:stderr]) unless cmd_res[:success]
          end
        else
          raise res[:stderr] || "git clone error"
        end
      end
    end

    def check_known_hosts!
      git_host = if m = @git_url.match(/.+@(.+?):/)
        m[1]
      elsif m = @git_url.match(/https?:\/\/(.+?)\//)
        m[1]
      else
        KubeBackup.logger.warn "Can't parse git url, skip ssh-keyscan"
        nil
      end

      if git_host
        known_hosts = "#{ENV['HOME']}/.ssh/known_hosts"

        if File.exist?(known_hosts)
          content = File.open(known_hosts, 'r:utf-8', &:read)
          if content.split("\n").any? {|l| l.strip.start_with?("#{git_host},", "#{git_host} ") }
            KubeBackup.logger.info "File #{known_hosts} already contain #{git_host}"
            return
          end
        end

        res = KubeBackup.cmd(%{ssh-keyscan -H #{git_host} >> #{known_hosts}})

        if res[:success]
          KubeBackup.logger.info "Added #{git_host} to #{known_hosts}"
        else
          KubeBackup.logger.error res[:stderr]
          raise res[:stderr] || "git clone error"
        end
      end
    end
  end
end
