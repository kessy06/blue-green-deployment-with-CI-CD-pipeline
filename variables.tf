variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
  default     = "647540925028"
}
   ###
# variable "active_environment" {
#   description = "Which environment should receive traffic (blue or green)"
#   type        = string
#   default     = "blue"
#   validation {
#     condition     = contains(["blue", "green"], var.active_environment)
#     error_message = "Active environment must be either 'blue' or 'green'."
#   }
# }
   ###