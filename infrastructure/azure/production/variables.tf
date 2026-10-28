variable "azure_region" {
  description = "Azure region for all resources"
  type        = string
  default     = "East US"
}

variable "db_password" {
  description = "Database administrator password"
  type        = string
  sensitive   = true
  default     = "production_secret_2024!"
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Project name used in resource naming"
  type        = string
  default     = "course-platform"
}
