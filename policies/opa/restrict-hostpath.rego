package kubernetes.admission

# Deny hostPath volumes
deny[msg] {
    input.kind == "Pod"
    volume := input.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed"
}

# Deny hostPath volumes in StatefulSets
deny[msg] {
    input.kind == "StatefulSet"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in StatefulSets"
}

# Deny hostPath volumes in Deployments
deny[msg] {
    input.kind == "Deployment"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in Deployments"
}

# Deny hostPath volumes in DaemonSets
deny[msg] {
    input.kind == "DaemonSet"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in DaemonSets"
}

# Deny hostPath volumes in Jobs
deny[msg] {
    input.kind == "Job"
    volume := input.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in Jobs"
}

# Deny hostPath volumes in CronJobs
deny[msg] {
    input.kind == "CronJob"
    volume := input.spec.jobTemplate.spec.template.spec.volumes[_]
    volume.hostPath
    msg := "hostPath volumes are not allowed in CronJobs"
}

# Allow specific hostPath volumes for system components (with exceptions)
allowed_hostpaths := {
    "/var/lib/rancher/k3s/storage",
    "/var/log",
    "/tmp"
}

deny[msg] {
    input.kind == "Pod"
    volume := input.spec.volumes[_]
    volume.hostPath
    not allowed_hostpaths[volume.hostPath.path]
    msg := sprintf("hostPath %s is not in the allowed list", [volume.hostPath.path])
}
