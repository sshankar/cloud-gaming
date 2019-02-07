# Environment Variables Needed
# AWS_DEFAULT_REGION if .aws/config doesn't have a region specified.

# Optional Parameters
variable "vpc_id" {
  description = "The ID of the VPC in which the nodes will be deployed.  Uses default VPC if not supplied."
  default     = ""
}

variable "ami_id" {
  description = "The ID of the AMI to run. This should be an AMI built from any cloud gaming box recipie"
  default     = ""
}

variable "spot_instance_type" {
  description = "AWS Instance Type to bid for."
  default     = "g3.4xlarge"
}

variable "iot_button_gsn" {
  description = "Serial number of the AWS IOT Button. When empty, no triggers are created."
  default     = ""
}