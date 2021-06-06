terraform {
  backend "azurerm" {
    storage_account_name  = "terraformstate1994"
    container_name        = "terraformstate"
    key                   = "loadbalancer.terraform.tfstate"
  }
}

provider "azurerm" { 
  version = "~>2.46"
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

resource "azurerm_network_interface" "ni" {
  count               = 2
  name                = "linuxvm-nic${count.index}"
  location            = azurerm_resource_group.rg1.location
  resource_group_name = azurerm_resource_group.rg1.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.sub.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_availability_set" "lbset" {
  name                         = "lb-a-set"
  location                     = azurerm_resource_group.rg1.location
  resource_group_name          = azurerm_resource_group.rg1.name
  platform_fault_domain_count  = 2
  platform_update_domain_count = 2
  managed                      = true
}

resource "azurerm_linux_virtual_machine" "lvm" {
  count               = 2
  name                = "linux-testserver${count.index}"
  resource_group_name = azurerm_resource_group.rg1.name
  location            = azurerm_resource_group.rg1.location
  availability_set_id = azurerm_availability_set.lbset.id
  size                = "Standard_B1S"
  admin_username      = "sudoer"
  network_interface_ids = [ element(azurerm_network_interface.ni.*.id, count.index)  ]

  admin_ssh_key {
    username   = "sudoer"
    public_key = azurerm_ssh_public_key.key.public_key
  }

  os_disk {
    name = "osdisk${count.index}"
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

resource "azurerm_lb" "lb" {
  name = "azure-lb"
  resource_group_name = azurerm_resource_group.rg1.name
  location = azurerm_resource_group.rg1.location
  sku = "Basic"

  frontend_ip_configuration {
    name = "lb-ip-config"
    public_ip_address_id = azurerm_public_ip.pubkey.id

  }
}

resource "azurerm_lb_backend_address_pool" "lbbackend" {
  name = "backend"
  loadbalancer_id = azurerm_lb.lb.id
  
}

resource "azurerm_network_interface_backend_address_pool_association" "assbp-01" {
  count                   = 2
  network_interface_id    = element(azurerm_network_interface.ni.*.id,count.index)
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbbackend.id
}
resource "azurerm_lb_probe" "probe" {
  name = "lb-probe"
  resource_group_name = azurerm_resource_group.rg1.name
  loadbalancer_id = azurerm_lb.lb.id
  protocol = "Tcp"
  port = "80"
  interval_in_seconds = "5"
  number_of_probes = "2"

}

resource "azurerm_lb_rule" "lbrule" {
  name = "lbrule"
  resource_group_name = azurerm_resource_group.rg1.name
  loadbalancer_id = azurerm_lb.lb.id
  protocol = "Tcp"
  frontend_port = "80"
  backend_port = "80"
  frontend_ip_configuration_name = azurerm_lb.lb.frontend_ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.lbbackend.id
  idle_timeout_in_minutes = "5"
  probe_id = azurerm_lb_probe.probe.id
}