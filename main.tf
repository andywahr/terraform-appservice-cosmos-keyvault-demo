variable "location" {
  type    = "string"
  default = "centralus"
}

variable "namePrefix" {
  type    = "string"
}

data "azurerm_client_config" "current" {}

resource "azurerm_resource_group" "resourceGroup" {
  name     = "rg-${var.namePrefix}"
  location = "${var.location}"
}

resource "azurerm_storage_account" "storageAccount" {
  name                      = "storn${var.namePrefix}"
  location                  = "${azurerm_resource_group.resourceGroup.location}"
  resource_group_name       = "${azurerm_resource_group.resourceGroup.name}"
  enable_https_traffic_only = true
  account_tier              = "Standard"
  account_replication_type  = "LRS"
  enable_blob_encryption    = true
  enable_file_encryption    = true
}

resource "azurerm_application_insights" "appInsights" {
  name                = "${var.namePrefix}appInsights"
  location            = "southcentralus"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
  application_type    = "Web"
}

resource "azurerm_app_service_plan" "webSiteAppServicePlan" {
  name                = "asp-${var.namePrefix}"
  location            = "${azurerm_resource_group.resourceGroup.location}"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"

  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_cosmosdb_account" "cosmosdb" {
  name                = "cosmos-${var.namePrefix}"
  location            = "${azurerm_resource_group.resourceGroup.location}"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  enable_automatic_failover = false

  consistency_policy {
    consistency_level = "Strong"
  }

  geo_location {
    location          = "${azurerm_resource_group.resourceGroup.location}"
    failover_priority = 0
  }
}

resource "azurerm_app_service" "webSite" {
  name                = "${var.namePrefix}-web"
  location            = "${azurerm_resource_group.resourceGroup.location}"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
  app_service_plan_id = "${azurerm_app_service_plan.webSiteAppServicePlan.id}"

  identity {
    type = "SystemAssigned"
  }

  app_settings {
    "KeyVaultAccountName"            = "kv${var.namePrefix}"
    "APPINSIGHTS_INSTRUMENTATIONKEY" = "${azurerm_application_insights.appInsights.instrumentation_key}"
    "WEBSITE_NODE_DEFAULT_VERSION"   = "10.0.0"
    "StorageAccountKey"              = "${azurerm_storage_account.storageAccount.primary_access_key}"
    "StorageAccountName"             = "${azurerm_storage_account.storageAccount.name}"
    "CosmosAccountName"              = "${azurerm_cosmosdb_account.cosmosdb.name}"
    "CosmosAccountPassword"          = "${azurerm_cosmosdb_account.cosmosdb.primary_master_key}"

    #Add any additional app settings needed    
  }
}

resource "azurerm_key_vault" "keyVault" {
  name                = "kv${var.namePrefix}"
  location            = "${azurerm_resource_group.resourceGroup.location}"
  resource_group_name = "${azurerm_resource_group.resourceGroup.name}"
  tenant_id           = "${data.azurerm_client_config.current.tenant_id}"

  sku {
    name = "standard"
  }

  access_policy {
    tenant_id = "${data.azurerm_client_config.current.tenant_id}"
    object_id = "${data.azurerm_client_config.current.service_principal_object_id}"

    secret_permissions = [
      "get",
      "list",
      "set",
    ]
  }

  access_policy {
    tenant_id = "${data.azurerm_client_config.current.tenant_id}"
    object_id = "${azurerm_app_service.webSite.identity.0.principal_id}"

    secret_permissions = [
      "get",
      "list"
    ]
  }
}