output "private_key" {
  value     = "${tls_private_key.generated.private_key_pem}"
  sensitive = true
}

output "launch_templates" {
  value = "${zipmap(aws_launch_template.box.*.id, aws_launch_template.box.*.latest_version)}"
}
