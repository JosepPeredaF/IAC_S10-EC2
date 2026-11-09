variable "region" {
  type = string
}

variable "profile" {
  type = string
}

variable "project_name" {
  type = string
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}

variable "backlog_objetivo" {
  description = "Mensajes en cola por instancia que el ASG intenta mantener"
  type        = number
  default     = 50
}