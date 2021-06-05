terraform {
  backend "azurerm" {
    storage_account_name  = "terraformstate1994"
    container_name        = "terraformstate"
    key                   = "loadbalancer.terraform.tfstate"
  }
}

provider "azurerm" { 
  version = "~>2.0"
  features {}
}


resource "azurerm_resource_group" "rg1" {
  name     = "lb_group"
  location = "West US"
}

resource "azurerm_storage_account" "storage" {
  name = "lbstorageaccount911"
  resource_group_name = azurerm_resource_group.rg1.name
  location = azurerm_resource_group.rg1.location
  account_tier = "Standard"
  account_replication_type = "LRS"
  tags = {
    "key" = "linux lb"
  }
}


resource "azurerm_public_ip" "pubkey" {
  name = "lb-pubip"
  resource_group_name = azurerm_resource_group.rg1.name
  location = azurerm_resource_group.rg1.location
  allocation_method = "Dynamic"
  tags = {
    "key" = "lb-ip"
  }
}

resource "azurerm_ssh_public_key" "key" {
  name = "linuxkey"
  resource_group_name = azurerm_resource_group.rg1.name
  location = azurerm_resource_group.rg1.location
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "azurerm_network_security_group" "nsg" {
    name = "lb-nsg"
    resource_group_name = azurerm_resource_group.rg1.name
    location = azurerm_resource_group.rg1.location

    security_rule  {
      destination_port_ranges = [ "22","80","443" ]
      direction = "Inbound"
      name = "lbrules"
      access ="Allow"
      priority = 100
      protocol = "Tcp"
      source_address_prefix = "*"
      source_port_range =  "*" 
      destination_address_prefix = "*"
    } 
  tags = {
    "key" = "lbnsg"
  }
}

resource "azurerm_virtual_network" "vn" {
  name = "lbnetwork"
  address_space = ["10.0.0.0/16"]
  resource_group_name = azurerm_resource_group.rg1.name
  location = azurerm_resource_group.rg1.location

}

resource "azurerm_subnet" "sub" {
  name = "internal"
  resource_group_name = azurerm_resource_group.rg1.name
  virtual_network_name = azurerm_virtual_network.vn.name
  address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic1" {
  name = "lbnic1"
  location = azurerm_resource_group.rg1.location
  resource_group_name = azurerm_resource_group.rg1.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.sub.id
    private_ip_address_allocation = "Dynamic"

  }
}

resource "azurerm_network_interface" "nic2" {
  name = "lbnic2"
  location = azurerm_resource_group.rg1.location
  resource_group_name = azurerm_resource_group.rg1.name

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.sub.id
    private_ip_address_allocation = "Dynamic"

  }
}

resource "azurerm_linux_virtual_machine" "lvm1" {
  name = "lbmachine1"
  resource_group_name = azurerm_resource_group.rg1.name
  location = azurerm_resource_group.rg1.location
  size = "Standard_B1S"
  admin_username = "sudoer"
  network_interface_ids = [ 
      azurerm_network_interface.nic1.id
   ]

    admin_ssh_key {
      username = "sudoer"
      public_key = azurerm_ssh_public_key.key.public_key       
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

}

resource "azurerm_linux_virtual_machine" "lvm2" {
  name = "lbmachine2"
  resource_group_name = azurerm_resource_group.rg1.name
  location = azurerm_resource_group.rg1.location
  size = "Standard_B1S"
  admin_username = "sudoer"
  network_interface_ids = [ 
      azurerm_network_interface.nic2.id
   ]

    admin_ssh_key {
      username = "sudoer"
      public_key = azurerm_ssh_public_key.key.public_key       
    }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}


