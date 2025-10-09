# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial infrastructure scaffold with k3d support
- Terraform modules for core platform components
- Kubernetes base manifests and overlays
- OPA policies for security enforcement
- Gatekeeper admission controller, Kyverno signature policy, and Trivy Operator for cluster security scanning
- Backup and restore scripts

### Changed
- StorageClasses now target the `rancher.io/local-path` provisioner and use `WaitForFirstConsumer` for compatibility with both kind and k3d

### Fixed

### Deprecated

### Security

## [0.1.0] - 2025-01-08

### Added
- Initial repository structure
- k3d cluster configuration
- Basic Terraform modules
- Kubernetes manifests scaffolding
