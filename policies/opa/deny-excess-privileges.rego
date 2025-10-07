package kubernetes.admission

# Deny pods with excessive privileges
deny contains msg if {
    input.kind == "Pod"
    some container in input.spec.containers
    container.securityContext.privileged == true
    msg := "Privileged pods are not allowed"
}

# Deny pods with hostPID
deny contains msg if {
    input.kind == "Pod"
    input.spec.hostPID == true
    msg := "hostPID is not allowed"
}

# Deny pods with hostIPC
deny contains msg if {
    input.kind == "Pod"
    input.spec.hostIPC == true
    msg := "hostIPC is not allowed"
}

# Deny pods with hostNetwork
deny contains msg if {
    input.kind == "Pod"
    input.spec.hostNetwork == true
    msg := "hostNetwork is not allowed"
}

# Deny containers with ALL capabilities
deny contains msg if {
    input.kind == "Pod"
    some container in input.spec.containers
    some capability in container.securityContext.capabilities.add
    capability == "ALL"
    msg := "ALL capabilities are not allowed"
}

# Deny containers with dangerous capabilities
dangerous_caps := {"SYS_ADMIN", "NET_ADMIN", "SYS_PTRACE", "SYS_MODULE", "SYS_RAWIO"}

deny contains msg if {
    input.kind == "Pod"
    some container in input.spec.containers
    some capability in container.securityContext.capabilities.add
    dangerous_caps[capability]
    msg := sprintf("Dangerous capability %s is not allowed", [capability])
}

# Deny containers running as root
deny contains msg if {
    input.kind == "Pod"
    some container in input.spec.containers
    container.securityContext.runAsUser == 0
    msg := "Containers must not run as root (runAsUser: 0)"
}

# Deny containers without security context
deny contains msg if {
    input.kind == "Pod"
    some container in input.spec.containers
    not container.securityContext
    msg := "All containers must have securityContext defined"
}

# Deny containers without resource limits
deny contains msg if {
    input.kind == "Pod"
    some container in input.spec.containers
    not container.resources.limits
    msg := "All containers must have resource limits defined"
}

# Deny containers without resource requests
deny contains msg if {
    input.kind == "Pod"
    some container in input.spec.containers
    not container.resources.requests
    msg := "All containers must have resource requests defined"
}
