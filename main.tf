# az network vnet subnet list --resource-group rg-senspuls-dev --vnet-name vnet-senspulse-dev --output table


resource "azurerm_resource_group" "rg" {
  name     = "rg-senspuls-dev"
  location = var.location
}

# vnet contains app-sub and db-sub
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-senspulse-dev"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
}

# subnet to connect the "outside" with my db-sub
resource "azurerm_subnet" "app" {
  name                 = "snet-app"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]

  delegation {
    name = "app-service-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

# postgres subnet
resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]

  delegation {
    name = "postgresql-delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

# private dns zone for postgresql
resource "azurerm_private_dns_zone" "dns" {
  name                = "senspulse.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# links vnet and dns
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "vnet-link-senspulse"
  private_dns_zone_name = azurerm_private_dns_zone.dns.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  resource_group_name   = azurerm_resource_group.rg.name
}

resource "azurerm_postgresql_flexible_server" "db" {
  name                = "psql-senspulse-dev-01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  # Hardware + Version
  version    = "16"
  sku_name   = "B_Standard_B1ms"
  storage_mb = 32768

  # login
  administrator_login    = var.db_username
  administrator_password = var.db_password

  # network Encapsulation
  delegated_subnet_id           = azurerm_subnet.db.id
  private_dns_zone_id           = azurerm_private_dns_zone.dns.id
  public_network_access_enabled = false

  depends_on = [azurerm_private_dns_zone_virtual_network_link.dns_link]

  lifecycle {
    ignore_changes = [
      zone,
      high_availability.0.standby_availability_zone
    ]
  }
}

resource "azurerm_service_plan" "asp" {
  name                = "asp-senspulse-dev"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_web_app" "alweb" {
  name                      = "app-senspulse-dev-chriscodecc"
  resource_group_name       = azurerm_resource_group.rg.name
  location                  = var.location
  service_plan_id           = azurerm_service_plan.asp.id
  virtual_network_subnet_id = azurerm_subnet.app.id

  site_config {
    application_stack {
      node_version = "20-lts"
    }
  }
}
