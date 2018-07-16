require 'commander'

class KubeBackup::CLI
  include Commander::Methods

  def default_args_from_env(defaults = {})
    args = defaults

    if ENV['GIT_REPO_URL']
      args[:repo_url] = ENV['GIT_REPO_URL']
    end

    vars = [
      :target_path, :skip_namespaces, :only_namespaces,
      :global_resources, :extra_global_resources, :skip_global_resources,
      :resources, :extra_resources, :skip_resources, :skip_objects,
      :git_user, :git_email
    ]

    vars.each do |var|
      env_value = ENV[var.to_s.upcase]
      if env_value
        args[var] = env_value
      end
    end

    if ENV['BACKUP_VERBOSE']
      args[:verbose] = ["1", "true", "yes", "ya"].include?(ENV['BACKUP_VERBOSE'].downcase)
      if args[:verbose]
        KubeBackup.verbose_logger!
      end
    end

    args
  end

  def run
    program :name, 'kube_backup'
    program :version, KubeBackup::VERSION
    program :description, 'Backup kubernetes resources to git'
    program :help_formatter, :compact
    program :help_paging, false

    global_option('--verbose', 'Verbose logging (env var BACKUP_VERBOSE)') {
      $verbose = true
      KubeBackup.verbose_logger!
    }

    command :backup do |c|
      c.syntax = 'kube_backup backup [options]'
      c.summary = 'Perform backup to local git repo'
      c.description = 'Create backup and save it in local folder'

      c.option '--repo-url VAL', 'Git repo URL (env var GIT_REPO_URL)'
      c.option '--target-path VAL', 'Local git path (env var TARGET_PATH)'

      c.option '--skip-namespaces VAL', 'Namespaces to skip, separated by coma'
      c.option '--only-namespaces VAL', 'Namespaces whitelist, separated by coma'

      c.option '--global-resources VAL', 'Override global resources list'
      c.option '--extra-global-resources VAL', 'Additional global resources'
      c.option '--skip-global-resources VAL', 'Global resources to exclude'

      c.option '--resources VAL', 'Override global resources list'
      c.option '--extra-resources VAL', 'Additional global resources'
      c.option '--skip-resources VAL', 'Resources to exclude'

      c.option '--skip-objects VAL', 'Skip objects, as namespaces/ObjectType/name. Also can use * for any segment as default/Secret/*,app/Pod/*'

      c.action do |args, options|
        options.default(default_args_from_env(target_path: "./kube_state"))
        KubeBackup.perform_backup!(options.__hash__)
      end
    end

    command :push do |c|
      c.syntax = 'kube_backup push [options]'
      c.summary = 'Push changes to remote git repo'
      c.description = 'Commit latest changes and put to remove repository'

      c.option '--repo-url VAL', 'Git repo URL (env var GIT_REPO_URL)'
      c.option '--target VAL', 'Local git path (env var TARGET_PATH)'

      c.option '--git-user VAL', 'Git username for commit (env var GIT_USER)'
      c.option '--git-email VAL', 'Git email for commit (env var GIT_EMAIL)'

      c.action do |args, options|
        options.default(default_args_from_env(target_path: "./kube_state"))

        KubeBackup.push_changes!(options.__hash__)
      end
    end

    run!
  end
end
