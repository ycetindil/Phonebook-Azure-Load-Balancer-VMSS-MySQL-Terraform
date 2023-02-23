terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.44.1"
    }
    github = {
      source  = "integrations/github"
      version = "5.18.0"
    }
  }
}

provider "azurerm" {
  features {}
}

provider "github" {
  token = file("${var.token_path}/${var.token_filename}")
}

##########
# GitHub #
##########
resource "github_repository_file" "dbendpoint" {
  content             = azurerm_mysql_flexible_server.db-server.fqdn
  file                = "dbserver.endpoint"
  repository          = var.repo_name
  branch              = var.repo_branch
  overwrite_on_create = true
  depends_on = [
    azurerm_mysql_flexible_server.db-server
  ]
}
##################
# Resource group #
##################
resource "azurerm_resource_group" "rg" {
  name     = "${var.prefix}-rg"
  location = var.location
}

###########################
# MySQL Flexible Database #
###########################
resource "azurerm_mysql_flexible_server" "db-server" {
  name                   = var.db_server_name
  resource_group_name    = azurerm_resource_group.rg.name
  location               = azurerm_resource_group.rg.location
  administrator_login    = var.db_username
  administrator_password = var.db_password
  sku_name               = "B_Standard_B1s"
  zone                   = "1"
}

resource "azurerm_mysql_flexible_server_configuration" "require-secure-transport" {
  name                = "require_secure_transport"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db-server.name
  value               = "OFF"
}

resource "azurerm_mysql_flexible_database" "db" {
  name                = var.prefix
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db-server.name
  charset             = "latin1"
  collation           = "latin1_general_ci"
}

resource "azurerm_mysql_flexible_server_firewall_rule" "allow-azure-resources" {
  name                = "AllowAzureResources"
  resource_group_name = azurerm_resource_group.rg.name
  server_name         = azurerm_mysql_flexible_server.db-server.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

#################
# VNet & Subnet #
#################
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.prefix}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.prefix}-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

#################
# Load Balancer #
#################
resource "azurerm_lb" "lb" {
  name                = "${var.prefix}-lb"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  frontend_ip_configuration {
    name                 = "Frontend"
    public_ip_address_id = azurerm_public_ip.pip.id
  }
}

resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}-pip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  domain_name_label   = azurerm_mysql_flexible_server.db-server.name
}

resource "azurerm_lb_backend_address_pool" "bapool" {
  name            = "BackendAddressPool"
  loadbalancer_id = azurerm_lb.lb.id
}

resource "azurerm_lb_probe" "hp-http" {
  name            = "health-probe-http"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Tcp"
  port            = 80
}

resource "azurerm_lb_probe" "hp-ssh" {
  name            = "health-probe-ssh"
  loadbalancer_id = azurerm_lb.lb.id
  protocol        = "Tcp"
  port            = 22
}

resource "azurerm_lb_rule" "lb-rule-http" {
  name                           = "lb-rule-http"
  loadbalancer_id                = azurerm_lb.lb.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bapool.id]
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 5
  frontend_ip_configuration_name = "Frontend"
  probe_id                       = azurerm_lb_probe.hp-http.id
}

resource "azurerm_lb_rule" "lb-rule-ssh" {
  name                           = "lb-rule-ssh"
  loadbalancer_id                = azurerm_lb.lb.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bapool.id]
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  enable_floating_ip             = false
  idle_timeout_in_minutes        = 5
  frontend_ip_configuration_name = "Frontend"
  probe_id                       = azurerm_lb_probe.hp-ssh.id
}

########
# VMSS #
########
# SSH Key
data "azurerm_ssh_public_key" "ssh_public_key" {
  resource_group_name = var.ssh_key_rg
  name                = var.ssh_key_name
}

# NSG
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.prefix}-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_linux_virtual_machine_scale_set" "vmss" {
  name                = "${var.prefix}-vmss"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Standard_F2"
  instances           = 2
  admin_username      = var.vmss_username
  custom_data         = base64encode(file("${path.module}/userdata.sh"))

  admin_ssh_key {
	username   = var.vmss_username
	public_key = data.azurerm_ssh_public_key.ssh_public_key.public_key
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  network_interface {
    name                      = "vmss-ni"
    primary                   = true
    network_security_group_id = azurerm_network_security_group.nsg.id

    ip_configuration {
      name                                   = "internal"
      primary                                = true
      subnet_id                              = azurerm_subnet.subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bapool.id]
    }
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  # Since these can change via auto-scaling outside of Terraform,
  # let's ignore any changes to the number of instances
  lifecycle {
    ignore_changes = [ instances ]
  }
}

resource "azurerm_monitor_autoscale_setting" "auto-scale-config" {
  name                = "autoscale-config"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.vmss.id

  profile {
    name = "AutoScale"

    capacity {
      default = 2
      minimum = 1
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.vmss.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}