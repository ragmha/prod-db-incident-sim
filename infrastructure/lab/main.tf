# The lab's production platform, configured the way the incident's platform was:
#
#   - Terraform state lives only on this machine: there is no backend block.
#   - Nothing stops `terraform destroy` from deleting the database.
#   - Deleting the database also deletes its automated backups.
#
# Terraform calls scripts/lab/control-plane.sh, the lab's stand-in for a cloud
# API, to create and delete the database on the local PostgreSQL server.
# Step 4 asks you to change this configuration. Keep the resource address
# terraform_data.course_platform_db stable: the replay and the coach rely on it.

terraform {
  required_version = ">= 1.6.0"
}

resource "terraform_data" "course_platform_db" {
  input = {
    name = "course_platform"

    # Mirrors aws_db_instance.delete_automated_backups. When true, deleting the
    # database also deletes the automated backups stored on the server.
    delete_automated_backups = true
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/../../scripts/lab/control-plane.sh create-database ${self.input.name}"
  }

  provisioner "local-exec" {
    when    = destroy
    command = "bash ${path.module}/../../scripts/lab/control-plane.sh delete-database ${self.input.name} ${self.input.delete_automated_backups}"
  }
}

output "database" {
  value = terraform_data.course_platform_db.output.name
}
