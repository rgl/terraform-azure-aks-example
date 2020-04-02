# see https://github.com/hashicorp/terraform
terraform {
  required_version = ">= 0.12"
}

# see https://github.com/terraform-providers/terraform-provider-azurerm
provider "azurerm" {
  version = "~> 2.3"
  features {}
}

# NB you can test the relative speed from you browser to a location using https://azurespeedtest.azurewebsites.net/
# get the available locations with: az account list-locations --output table
variable "location" {
  default = "France Central" # see https://azure.microsoft.com/en-us/global-infrastructure/france/
}

# NB this name must be unique within the Azure subscription.
#    all the other names must be unique within this resource group.
variable "resource_group_name" {
  default = "rgl-aks-example"
}

variable "tags" {
  type = map

  default = {
    owner = "rgl"
  }
}

variable "admin_username" {
  default = "rgl"
}

variable "admin_password" {
  default = "HeyH0Password"
}

# NB when you run make terraform-apply this is set from the
#    TF_VAR_admin_ssh_key_data environment variable, which
#    comes from the ~/.ssh/id_rsa.pub file.
variable "admin_ssh_key_data" {}

# NB when you run make terraform-apply this is set from the
#    TF_VAR_service_principal_client_id environment variable,
#    which comes from the service-principal.json file.
variable "service_principal_client_id" {}
  
# NB when you run make terraform-apply this is set from the
#    TF_VAR_service_principal_client_secret environment variable,
#    which comes from the service-principal.json file.
variable "service_principal_client_secret" {}

output "kube_config" {
  sensitive = true
  value     = azurerm_kubernetes_cluster.example.kube_config_raw
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name # NB this name must be unique within the Azure subscription.
  location = var.location
  tags     = var.tags
}

# see https://www.terraform.io/docs/providers/azurerm/r/kubernetes_cluster.html
# see https://docs.microsoft.com/en-us/azure/aks/
resource "azurerm_kubernetes_cluster" "example" {
  name                = "example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  dns_prefix         = "example"
  kubernetes_version = "1.17.3"

  default_node_pool {
    name            = "default"
    vm_size         = "Standard_D1_v2"
    os_disk_size_gb = 30
    node_count      = 1
  }

  linux_profile {
    admin_username = var.admin_username

    ssh_key {
      key_data = var.admin_ssh_key_data
    }
  }

  addon_profile {
    kube_dashboard {
      enabled = true
    }
  }

  role_based_access_control {
    enabled = true
  }

  service_principal {
    client_id     = var.service_principal_client_id
    client_secret = var.service_principal_client_secret
  }

  tags = var.tags
}
