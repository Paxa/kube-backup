require_relative './kube_backup/version'
require_relative './kube_backup/cmd_utils'
require_relative './kube_backup/log_util'
require_relative './kube_backup/writter'
require_relative './kube_backup/logger'
require_relative './kube_backup/plugins/grafana'

require 'json'
require 'yaml'
require 'colorize'

module KubeBackup
  module Plugins; end

  extend KubeBackup::CmdUtils
  extend KubeBackup::Logger

  GLOBAL_TYPES = [
    :node,
    :apiservice,
    :clusterrole,
    :clusterrolebinding,
    :podsecuritypolicy,
    :storageclass,
    :persistentvolume,
    :customresourcedefinition,
    :mutatingwebhookconfiguration,
    :validatingwebhookconfiguration,
    :priorityclass
  ].freeze

  TYPES = [
    :serviceaccount,
    :secret,
    :deployment,
    :daemonset,
    :statefulset,
    :configmap,
    :cronjob,
    :job,
    :ingress,
    :networkpolicy,
    :persistentvolumeclaim,
    :role,
    :rolebinding,
    :service,
    :pod,
    :endpoints,
    :resourcequota,
    :horizontalpodautoscaler,
    :limitrange,
    :podtemplate,
    :poddisruptionbudget
  ].freeze

  SKIP_POD_OWNERS = [
    "DaemonSet",
    "ReplicaSet",
    "Job",
    "StatefulSet"
  ].freeze

  SKIP_JOB_OWNERS = [
    "CronJob",
  ].freeze


  def self.perform_backup!(options = {})
    logger.info "Args: #{LogUtil.hash(options)}"

    if !options[:repo_url] || options[:repo_url] == ''
      raise OptionParser::MissingArgument, "Git repo-url is required, please specify --repo-url or GIT_REPO_URL"
    end

    global_types = combine_types(GLOBAL_TYPES.dup,
      extras: options[:extra_global_resources],
      exclude: options[:skip_global_resources],
      only: options[:global_resources]
    )
    if global_types != GLOBAL_TYPES
      logger.info "Global Types: #{LogUtil.dump(global_types)}"
    end

    types = combine_types(TYPES.dup,
      extras: options[:extra_resources],
      exclude: options[:skip_resources],
      only: options[:resources]
    )
    if types != TYPES
      logger.info "Types: #{LogUtil.dump(types)}"
    end

    skip_patterns = (options[:skip_objects] || "").split(",").map(&:strip)
    global_skip_patterns = skip_patterns.select {|pattern| pattern.scan("/").size == 1 }
    skip_patterns -= global_skip_patterns

    if global_skip_patterns.size > 0
      logger.info "Global Skip Patterns: #{LogUtil.dump(global_skip_patterns)}"
    end
    if skip_patterns.size > 0
      logger.info "Skip Patterns: #{LogUtil.dump(skip_patterns)}"
    end

    skip_namespaces = options[:skip_namespaces] ? options[:skip_namespaces].split(",") : []
    skip_namespaces_regex = options[:skip_namespaces_regex] ? options[:skip_namespaces_regex] : nil
    only_namespaces = options[:only_namespaces] ? options[:only_namespaces].split(",") : nil

    writter = Writter.new(options)
    writter.init_repo!

    global_types.each do |type|
      resources = kubectl(:get, type)
      puts "Got #{resources["items"].size} #{type}s"

      resources["items"].each do |item|

        if skip_object?(item, global_skip_patterns)
          name = item.dig("metadata", "name")
          logger.info "skip resource #{item["kind"]}/#{name}"
          next
        end

        clean_resource!(item)
        writter.write_res(item)
      end
    end

    types.each do |type|
      resources = kubectl(:get, type, "all-namespaces" => nil)
      puts "Got #{resources["items"].size} #{type}s"

      if !resources["items"]
        logger.error "Can not get resource #{type}"
        puts JSON.pretty_generate(resources)
        exit(1)
      end

      resources["items"].each do |item|

        if item["kind"] == "Secret" && item["type"] == "kubernetes.io/service-account-token"
          next
        end

        # skip pods with ownerReferences (means created by deployment, cronjob, daemonset)
        if item["kind"] == "Pod" && item.dig("metadata", "ownerReferences")
          if item["metadata"]["ownerReferences"].size > 1
            puts YAML.dump(item)
            raise "many ownerReferences"
          end

          ref = item["metadata"]["ownerReferences"].first
          next if SKIP_POD_OWNERS.include?(ref["kind"])
        end

        if item["kind"] == "Job" && item.dig("metadata", "ownerReferences")
          if item["metadata"]["ownerReferences"].size > 1
            puts YAML.dump(item)
            raise "many ownerReferences"
          end
          ref = item["metadata"]["ownerReferences"].first
          next if SKIP_JOB_OWNERS.include?(ref["kind"])
        end

        if item["kind"] == "Endpoints"
          if item["subsets"] && item["subsets"][0]
            if addresses = item["subsets"][0]["addresses"] || addresses = item["subsets"][0]["notReadyAddresses"]
              if addresses[0] && addresses[0]["targetRef"] && addresses[0]["targetRef"]["kind"] == "Pod"
                # skip endpoints created by services
                next
              end
            end
          end
        end

        namespace = item.dig("metadata", "namespace")

        if skip_namespaces_regex && namespace.match(skip_namespaces_regex)
          name = item.dig("metadata", "name")
          logger.info "skip resource #{namespace}/#{item["kind"]}/#{name} by skip_namespaces_regex filter"
          next
        end

        if skip_namespaces.include?(namespace)
          name = item.dig("metadata", "name")
          logger.info "skip resource #{namespace}/#{item["kind"]}/#{name} by namespace filter"
          next
        end

        if only_namespaces && !only_namespaces.include?(namespace)
          name = item.dig("metadata", "name")
          logger.info "skip resource #{namespace}/#{item["kind"]}/#{name} by namespace filter"
          next
        end

        if skip_object?(item, skip_patterns)
          name = item.dig("metadata", "name")
          logger.info "skip resource #{namespace}/#{item["kind"]}/#{name}"
          next
        end

        clean_resource!(item)
        item = sort_keys!(item)
        writter.write_ns_res(item)
      end
    end

    Plugins::Grafana.new(writter).run

    writter.print_changed_files
  end

  def self.kubectl(command, resource, options = {})
    options[:o] ||= 'json'

    args = options.to_a.map do |key, value|
      key = key.to_s
      key = "-#{key.size > 1 ? "-" : ""}#{key}"

      if value.nil?
        [key]
      else
        [key, "#{value}"]
      end
    end.flatten

    res = cmd("kubectl", command, resource, *args, ENV.to_h)

    if !res[:success]
      logger.error res[:stderr]
    end

    if res[:stdout] && res[:stdout].size > 0
      JSON.parse(res[:stdout])
    else
      {"items" => []} # dummy
    end
  end

  def self.clean_resource!(resource)
    resource.delete("status")

    if resource["metadata"]
      resource["metadata"].delete("creationTimestamp")
      resource["metadata"].delete("selfLink")
      resource["metadata"].delete("uid")
      resource["metadata"].delete("resourceVersion")
      resource["metadata"].delete("generation")

      if resource["metadata"]["annotations"]
        resource["metadata"]["annotations"].delete("kubectl.kubernetes.io/last-applied-configuration")
        resource["metadata"]["annotations"].delete("control-plane.alpha.kubernetes.io/leader")
        resource["metadata"]["annotations"].delete("deployment.kubernetes.io/revision")

        if resource["metadata"]["annotations"] == {}
          resource["metadata"].delete("annotations")
        end
      end

      if resource["metadata"]["namespace"] == ''
        resource["metadata"].delete("namespace")
      end

      if resource["metadata"] == {}
        resource.delete("metadata")
      end
    end

    if resource["kind"] == "Service" && resource["spec"]
      if resource["spec"]["clusterIP"] != "None"
        resource["spec"].delete("clusterIP")
      end
      if resource["spec"] == {}
        resource.delete("spec")
      end
    end

    if resource["kind"] == "Pod"
      resource["spec"].delete("nodeName")
      resource["spec"].delete("tolerations")

      _cleanup_pod_spec(resource["spec"])
    end

    if resource["kind"] == "Deployment" || resource["kind"] == "DaemonSet" || resource["kind"] == "StatefulSet"
      meta = resource.dig('spec', 'template', 'metadata')
      if meta.has_key?('creationTimestamp') && meta['creationTimestamp'].nil?
        meta.delete('creationTimestamp')
        if meta == {}
          resource['spec']['template'].delete('metadata')
        end
      end
      if resource['spec']['progressDeadlineSeconds'] == 600
        resource['spec'].delete('progressDeadlineSeconds')
      end
      _cleanup_pod_spec(resource.dig('spec', 'template', 'spec'))
    end

    if resource["kind"] == "CronJob"
      meta = resource.dig('spec', 'jobTemplate', 'metadata')
      if meta.has_key?('creationTimestamp') && meta['creationTimestamp'].nil?
        meta.delete('creationTimestamp')
        if meta == {}
          resource['spec']['jobTemplate'].delete('metadata')
        end
      end
      if resource['spec']['progressDeadlineSeconds'] == 600
        resource['spec'].delete('progressDeadlineSeconds')
      end
      _cleanup_pod_spec(resource.dig('spec', 'jobTemplate', 'spec'))
    end


    resource
  end

  def self._cleanup_pod_spec(pod_spec)
    if pod_spec['restartPolicy'] == "Always"
      pod_spec.delete('restartPolicy')
    end
    if pod_spec['schedulerName'] == "default-scheduler"
      pod_spec.delete('schedulerName')
    end
    if pod_spec['securityContext'] == {}
      pod_spec.delete('securityContext')
    end
    if pod_spec['terminationGracePeriodSeconds'] == 30
      pod_spec.delete('terminationGracePeriodSeconds')
    end
    if pod_spec['dnsPolicy'] == 'ClusterFirst'
      pod_spec.delete('dnsPolicy')
    end

    (pod_spec["containers"] || []).each do |container|
      _cleanup_container(container)
    end
  end

  def self._cleanup_container(container)
    if container['terminationMessagePath'] == "/dev/termination-log"
      container.delete('terminationMessagePath')
    end
    if container['terminationMessagePolicy'] == "File"
      container.delete('terminationMessagePolicy')
    end
  end

  def self.sort_keys!(resource)
    resource.sort_by do |k, v|
      if k == "apiVersion"
        "_0"
      elsif k == "kind"
        "_1"
      elsif k == "metadata"
        "_2"
      elsif k == "type"
        "_3"
      else
        k
      end
    end.to_h
  end

  def self.combine_types(types, extras:, exclude:, only:)
    if only
      return only.downcase.split(",").map(&:strip).map(&:to_sym)
    end

    if extras
      extras = extras.downcase.split(",").map(&:strip).map(&:to_sym)
      types.push(*extras)
    end

    if exclude
      exclude = exclude.downcase.split(",").map(&:strip).map(&:to_sym)
      types.delete_if {|r| exclude.include?(r) }
    end

    types
  end

  def self.skip_object?(item, patterns)
    return false if patterns.size == 0

    ns = item.dig("metadata", "namespace")
    ns = nil if ns == ''

    object_parts = [ns, item["kind"], item.dig("metadata", "name")].compact

    patterns.each do |pattern|
      pattern = pattern.downcase

      if pattern == object_parts.join("/").downcase
        return true
      end

      pattern_parts = pattern.split("/")
      mismatch = false
      object_parts.each_with_index do |part, index|
        if pattern_parts[index] == "*" || part.downcase == pattern_parts[index]
          # good
        else
          mismatch = true
        end
      end

      return true if !mismatch
    end

    return false
  end

  def self.push_changes!(options)
    writter = Writter.new(options)

    changes_list = writter.get_changes

    if changes_list
      changes_lines = changes_list.split("\n")
      namespaces = []
      resources = []

      prefix = options[:git_prefix] ? options[:git_prefix].sub(/\/$/, '') + "/" : false

      changes_lines.each do |line|
        line = line.strip.gsub('"', '')
        info = line.match(/^(?<prefix>.+?)\s+(?<file>.+)$/)
        info["file"].sub!(prefix, '') if prefix
        file_parts = info["file"].sub(/\.yaml$/, '').split("/")

        if file_parts[0] != "_global_"
          namespaces << file_parts[0]
        end
        resources << file_parts[1]
      end
      namespaces.uniq!
      resources.uniq!

      message = [
        "Updated",
        resources.size > 0 ? "#{resources.join(", ")}" : nil,
        namespaces.size > 0 ? "in namespace#{namespaces.size > 1 ? "s" : ""} #{namespaces.join(", ")}." : nil,
        "#{changes_lines.size} item#{changes_lines.size > 1 ? "s" : ""}"
      ].compact.join(" ")

      writter.push_changes!(message)
    end
  end

end
