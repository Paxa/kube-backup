# Kube-backup

Kubernetes resource state backup to git

### Git structure

```
_global_ - global resources such as Node, ClusterRole, StorageClass
_grafana_ - grafana configs (when grafana enabled)
<namespace> - such as kube-system, default, etc...
  <ResourceType> - folder for each resource type
    <resource-name.yaml> - file for each resource
```

### Screenshots
<img src="https://user-images.githubusercontent.com/26019/48974539-12be7600-f097-11e8-91d7-b19c4c8d3e23.png" width="40%"> <img src="https://user-images.githubusercontent.com/26019/48974571-b9a31200-f097-11e8-8f0a-52afc67e4112.png" width="57%">

### Deployment

Yaml manifests are in  [deploy folder](deploy).

#### Create Deployment Key

Github and gitlab support adding key only for one repository

* Create repo
* Generate ssh key `ssh-keygen -f ./new_key`
* Add new ssh key to repo with write access
* Save key to `2_config_map.yaml` (see comments in file)

#### Testing Deployment

I recommend to run it periodically with kubernetes' CronJob resource, if you want to test how it works without waiting then can change running schedule or create pod with same parameters

### Commands

* `kube_backup backup` - pull remote git repository, save kubernetes state, make git commit in local repository
* `kube_backup push` - push changes to remote repository
* `kube_backup help` - shows help

### Config

* `BACKUP_VERBOSE` use 1 to enable verbose logging
* `GIT_REPO_URL` - remote git URL
* `TARGET_PATH` - local git repository folder, default `./kube_state`
* `SKIP_NAMESPACES` - namespaces to exclude, separated by coma (,)
* `ONLY_NAMESPACES` - whitelist namespaces
* `GLOBAL_RESOURCES` - override global resources list, default is `node, apiservice, clusterrole, clusterrolebinding, podsecuritypolicy, storageclass, persistentvolume, customresourcedefinition, mutatingwebhookconfiguration, validatingwebhookconfiguration, priorityclass`
* `EXTRA_GLOBAL_RESOURCES` - use it to add resources to `GLOBAL_RESOURCES` list
* `SKIP_GLOBAL_RESOURCES` - blacklist global resources
* `RESOURCES` - default list of namespaces resources, see `KubeBackup::TYPES`
* `EXTRA_RESOURCES` - use it to add resources to `RESOURCES` list
* `SKIP_RESOURCES` - exclude resources
* `SKIP_OBJECTS` - use it to skip individual objects, such as `kube-backup/ConfigMap/kube-backup-ssh-config` (separated by coma, spaces around coma ignored)
* `GIT_USER` - default is `kube-backup`
* `GIT_EMAIL` - default is `kube-backup@$(HOSTNAME)`
* `GRAFANA_URL` - grafana api URL, e.g. `https://grafana.my-cluster.com`
* `GRAFANA_TOKEN` - grafana API token, create at https://your-grafana/org/apikeys
* `TZ` - timezone of commit times. e.g. `:Europe/Berlin`

#### Custom Resources

Let's say we have a cluster with prometheus and certmanager, they register custom resources and we want to add them in backup.

Get list of custom resource definitions:
```
$ kubectl get crd

NAME                                    CREATED AT
alertmanagers.monitoring.coreos.com     2018-06-27T10:33:00Z
certificates.certmanager.k8s.io         2018-06-27T09:39:43Z
clusterissuers.certmanager.k8s.io       2018-06-27T09:39:43Z
issuers.certmanager.k8s.io              2018-06-27T09:39:44Z
prometheuses.monitoring.coreos.com      2018-06-27T10:33:00Z
prometheusrules.monitoring.coreos.com   2018-06-27T10:33:00Z
servicemonitors.monitoring.coreos.com   2018-06-27T10:33:00Z
```

Or get more useful output:
```
$ kubectl get crd -o json | jq -r '.items | (.[] | [.spec.names.singular, .spec.group, .spec.scope]) | @tsv'
alertmanager    monitoring.coreos.com  Namespaced
certificate     certmanager.k8s.io     Namespaced
clusterissuer   certmanager.k8s.io     Cluster
issuer          certmanager.k8s.io     Namespaced
prometheus      monitoring.coreos.com  Namespaced
prometheusrule  monitoring.coreos.com  Namespaced
servicemonitor  monitoring.coreos.com  Namespaced
```

Set env variables in container spec:
```yaml
env:
  - name: EXTRA_GLOBAL_RESOURCES
    value: clusterissuer
  - name: EXTRA_RESOURCES
    value: alertmanager, prometheus, prometheusrule, servicemonitor, certificate, issuer
```
