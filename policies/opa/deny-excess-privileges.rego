package kubernetes.admission

# Deny pods with excessive privileges
deny[msg] {
    input.kind == "Pod"
    input.spec.containers[_].securityContext.privileged == true
    msg := "Privileged pods are not allowed"
}

# Deny pods with hostPID
deny[msg] {
    input.kind == "Pod"
    input.spec.hostPID == true
    msg := "hostPID is not allowed"
}

# Deny pods with hostIPC
deny[msg] {
    input.kind == "Pod"
    input.spec.hostIPC == true
    msg := "hostIPC is not allowed"
}

# Deny pods with hostNetwork
deny[msg] {
    input.kind == "Pod"
    input.spec.hostNetwork == true
    msg := "hostNetwork is not allowed"
}

# Deny containers with ALL capabilities
deny[msg] {
    input.kind == "Pod"
    input.spec.containers[_].securityContext.capabilities.add[_] == "ALL"
    msg := "ALL capabilities are not allowed"
}

# Deny containers with dangerous capabilities
dangerous_caps := {"SYS_ADMIN", "NET_ADMIN", "SYS_PTRACE", "SYS_MODULE", "SYS_RAWIO"}

deny[msg] {
    input.kind == "Pod"
    cap := input.spec.containers[_].securityContext.capabilities.add[_]
    dangerous_caps[cap]
    msg := sprintf("Dangerous capability %s is not allowed", [cap])
}

# Deny containers running as root
deny[msg] {
    input.kind == "Pod"
    input.spec.containers[_].securityContext.runAsUser == 0
    msg := "Containers must not run as root (runAsUser: 0)"
}

# Deny containers without security context
deny[msg] {
    input.kind == "Pod"
    not input.spec.containers[_].securityContext
    msg := "All containers must have securityContext defined"
}

# Deny containers without resource limits
deny[msg] {
    input.kind == "Pod"
    not input.spec.containers[_].resources.limits
    msg := "All containers must have resource limits defined"
}

# Deny containers without resource requests
deny[msg] {
    input.kind == "Pod"
    not input.spec.containers[_].resources.requests
    msg := "All containers must have resource requests defined"
}
