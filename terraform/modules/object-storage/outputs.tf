output "bucket_names" {
  description = "Map of created bucket names"
  value       = { for k, v in oci_objectstorage_bucket.buckets : k => v.name }
}
