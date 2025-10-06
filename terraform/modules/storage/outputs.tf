output "fast_local_storage_class" {
  description = "Name of the fast local storage class"
  value       = kubernetes_storage_class.fast_local.metadata[0].name
}

output "standard_local_storage_class" {
  description = "Name of the standard local storage class"
  value       = kubernetes_storage_class.standard_local.metadata[0].name
}

output "backup_storage_class" {
  description = "Name of the backup storage class"
  value       = kubernetes_storage_class.backup_storage.metadata[0].name
}
