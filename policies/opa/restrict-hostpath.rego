package kubernetes.admission

# Deny hostPath volumes
deny contains msg if {
    input.kind == "Pod"
    volume := input.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed"
}

# Deny hostPath volumes in StatefulSets
deny contains msg if {
    input.kind == "StatefulSet"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in StatefulSets"
}

# Deny hostPath volumes in Deployments
deny contains msg if {
    input.kind == "Deployment"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in Deployments"
}

# Deny hostPath volumes in DaemonSets
deny contains msg if {
    input.kind == "DaemonSet"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in DaemonSets"
}

# Deny hostPath volumes in Jobs
deny contains msg if {
    input.kind == "Job"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in Jobs"
}

# Deny hostPath volumes in CronJobs
deny contains msg if {
    input.kind == "CronJob"
    volume := input.spec.jobTemplate.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in CronJobs"
}

# Allow specific hostPath volumes for system components (with exceptions)
allowed_hostpaths := {
    "/var/lib/rancher/k3s/storage",
    "/var/local-path-provisioner",
    "/opt/local-path-provisioner",
    "/var/log",
    "/tmp"
}

deny contains msg if {
    input.kind == "Pod"
    volume := input.spec.volumes[_]
    volume.hostPath
    not allowed_hostpaths[volume.hostPath.path]
    msg := sprintf("hostPath %s is not in the allowed list", [volume.hostPath.path])
}
