
####### Variables for IPAM #######

variable "PHPIPAM_APP_ID" {
    type = string
}

variable "PHPIPAM_ENDPOINT_ADDR" {
    type = string  
}

variable "PHPIPAM_PASSWORD" {
    type = string
  #  sensitive = false
}
variable "PHPIPAM_USER_NAME" {
  type = string
}

variable "phpipam_subnet_address" {
    type = string
}
variable "phpipam_subnet_mask" {
    type = number
}
variable "vm_name" {
    type = string
}
variable "phpipam_newip_description" {
  type = string
}


##### Variables for VSPHERE ######

variable "vsphere_server" {
    type = string
}
variable "vsphere_user" {
   type = string
}
variable "vsphere_pass" {
    type = string
    sensitive = "true"
}
variable "dc_name"{
   }
variable "datastore_name" {
  }
variable "cluster_name" {
  }
variable "network_name" {
  }
variable "template_name" {
  }
variable "vm_num_cpus"{
    type = number
 }
variable "vm_memory" {
    type = number
    description = "1024 minimum value for memory is 1024 for ubuntu img"
  }
variable "disk_label" {
    type = string
 }
variable "disk_size" {
  type = number
}

variable "swap" {
  type = bool
}

variable "swap_size" {
  type = number
}

variable "domain" {
   type = string
  }
variable "ssh_user" {
  }
variable "ssh_password" {
  }
variable "ansible_working_dir" {
}

variable "ipgwv4" {
  type = string
}