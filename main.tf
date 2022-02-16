###Create single machine#### 

terraform {
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "2.0.2"
    }
    phpipam = {
      source  = "lord-kyron/phpipam"
      version = "1.2.8"
    }

  }
}

####RESERVE the first available address and create a machine
provider "phpipam" {
  app_id   =  var.PHPIPAM_APP_ID
  endpoint =  var.PHPIPAM_ENDPOINT_ADDR 
  password =  var.PHPIPAM_PASSWORD
  username =  var.PHPIPAM_USER_NAME
  # insecure = true
}

####TAKE  the first free address and assign it to a machine##### 
// Look up the subnet
data "phpipam_subnet" "subnet" {
  subnet_address =  var.phpipam_subnet_address 
  subnet_mask    =  var.phpipam_subnet_mask
}

// Get the first available address
data "phpipam_first_free_address" "next_address" {
  subnet_id = data.phpipam_subnet.subnet.subnet_id
}

// Reserve the address. Note that we use ignore_changes here to ensure that we
// don't end up re-allocating this address on future Terraform runs.
resource "phpipam_address" "newip" {
  subnet_id   = data.phpipam_subnet.subnet.subnet_id
  ip_address  = data.phpipam_first_free_address.next_address.ip_address
  hostname    = var.vm_name
  description = var.phpipam_newip_description

  lifecycle {
    ignore_changes = [
      subnet_id,
      ip_address,
    ]
  }
}

provider "vsphere" {
  user           = var.vsphere_user
  password       = var.vsphere_pass
  vsphere_server = var.vsphere_server
  # If you have a self-signed cert
  allow_unverified_ssl = true
}

################################################
#Capturing the data from vsphere
#################################################
data "vsphere_datacenter" "dc" {
  name =  var.dc_name
}

data "vsphere_datastore" "datastore" {
  name          =  var.datastore_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_compute_cluster" "cluster" {
  name          =  var.cluster_name
  datacenter_id = data.vsphere_datacenter.dc.id
}
data "vsphere_network" "network" {
  name          =  var.network_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

########################################################
# sourcing template
#############################################################
data "vsphere_virtual_machine" "template" {
  name          = var.template_name
  datacenter_id = data.vsphere_datacenter.dc.id
}

########################################################
##Resource
#########################################################
resource "vsphere_virtual_machine" "vm" {
  #count = 2
  name = var.vm_name
  ##name = "terraform-test${count.index}"
  resource_pool_id = data.vsphere_compute_cluster.cluster.resource_pool_id
  datastore_id     = data.vsphere_datastore.datastore.id

  num_cpus = var.vm_num_cpus
  memory   = var.vm_memory
  guest_id = "ubuntu64Guest"

  network_interface {
    network_id = data.vsphere_network.network.id
  }

  disk {
    label = var.disk_label
    size  = var.disk_size

  }
  disk {
    label = "disk1"
    size = var.swap_size
    unit_number = 1
  }
  ###############################################################
  ##Initiate the clone
  ################################################################
  clone {
    template_uuid = data.vsphere_virtual_machine.template.id

    customize {
      linux_options {
        host_name = var.vm_name

        domain = var.domain
      }

      network_interface {

        ipv4_address = data.phpipam_first_free_address.next_address.ip_address
        ipv4_netmask = data.phpipam_subnet.subnet.subnet_mask
      }

      ipv4_gateway    = var.ipgwv4
      dns_server_list = ["10.0.20.10", "10.1.20.10"]
    }
  }
  wait_for_guest_net_timeout = 0
  provisioner "local-exec" {
    command = "sleep 40"
  }

}
resource "null_resource" "FixDisk" {
  connection {
    type     = "ssh"
    user     =  var.ssh_user
    password =  var.ssh_password
    host     = data.phpipam_first_free_address.next_address.ip_address
  }
  provisioner "remote-exec" {
    inline = [
      "echo ${var.ssh_password} | sudo -S growpart /dev/sda 3 && sudo pvresize /dev/sda3 && sudo lvextend -r -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv",
      "echo ${var.ssh_password} | sudo -S mkswap /dev/sdb && sudo swapon /dev/sdb",
      "echo ${var.ssh_password} | sudo -S bash -c \"echo '/dev/sdb swap swap sw 0 0' >> /etc/fstab\"",      
    ]
  }
  depends_on = [vsphere_virtual_machine.vm]
}

resource "null_resource" "ansible_provision" {

  provisioner "local-exec" {
    working_dir =  var.ansible_working_dir
    command     = "ansible-playbook -u ${var.ssh_user} -e 'ansible_ssh_pass=${var.ssh_password} ansible_become_password=${var.ssh_password}' -i ${data.phpipam_first_free_address.next_address.ip_address}, initial_config.yml  -vv"

  }
  depends_on = [null_resource.FixDisk]
}

#####################################
##Output
#####################################
output "IP-Address" {
  value       = data.phpipam_first_free_address.next_address.ip_address
  description = "ip addresses"
}