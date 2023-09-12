# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.5.7"
  required_providers {
    # see https://github.com/hashicorp/terraform-provider-random
    # see https://registry.terraform.io/providers/hashicorp/random
    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }
    # see https://github.com/hashicorp/terraform-provider-time
    # see https://registry.terraform.io/providers/hashicorp/time
    time = {
      source  = "hashicorp/time"
      version = "0.9.1"
    }
    # see https://github.com/terraform-providers/terraform-provider-azuread
    # see https://registry.terraform.io/providers/hashicorp/azuread
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.41.0"
    }
    # see https://github.com/terraform-providers/terraform-provider-azurerm
    # see https://registry.terraform.io/providers/hashicorp/azurerm
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.72.0"
    }
    # see https://github.com/terraform-providers/terraform-provider-kubernetes
    # see https://registry.terraform.io/providers/hashicorp/kubernetes
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    # see https://github.com/terraform-providers/terraform-provider-helm
    # see https://registry.terraform.io/providers/hashicorp/helm
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
    # see https://registry.terraform.io/providers/gavinbunney/kubectl
    # see https://github.com/gavinbunney/terraform-provider-kubectl
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.14.0"
    }
  }
}

# see https://github.com/terraform-providers/terraform-provider-azurerm
provider "azurerm" {
  features {}
}

# see https://github.com/terraform-providers/terraform-provider-kubernetes
provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.example.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].cluster_ca_certificate)
}

# see https://registry.terraform.io/providers/gavinbunney/kubectl
# see https://github.com/gavinbunney/terraform-provider-kubectl
provider "kubectl" {
  load_config_file       = false
  host                   = azurerm_kubernetes_cluster.example.kube_config[0].host
  client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].client_certificate)
  client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].cluster_ca_certificate)
}

# see https://github.com/terraform-providers/terraform-provider-helm
provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.example.kube_config[0].host
    client_certificate     = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].client_certificate)
    client_key             = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.example.kube_config[0].cluster_ca_certificate)
  }
}

data "azuread_client_config" "current" {
}

data "azurerm_client_config" "current" {
}

# NB you can test the relative speed from you browser to a location using https://azurespeedtest.azurewebsites.net/
# get the available locations with: az account list-locations --output table
variable "location" {
  type    = string
  default = "northeurope"
}

# NB this name must be unique within the Azure subscription.
#    all the other names must be unique within this resource group.
variable "resource_group_name" {
  type    = string
  default = "rgl-aks-example"
}

variable "tags" {
  type = map(any)

  default = {
    owner = "rgl"
  }
}

variable "dns_zone" {
  type    = string
  default = "example.com"
}

# NB Let's Encrypt will use this to contact you about expiring
#    certificates and issues related to your account.
# see https://letsencrypt.org/docs/expiration-emails/
variable "letsencrypt_email" {
  type    = string
  default = "john.doe@example.com"
}

# the Let's Encrypt server to use.
# NB for production, you should change this from:
#       https://acme-staging-v02.api.letsencrypt.org/directory
#     to:
#       https://acme-v02.api.letsencrypt.org/directory
# see https://letsencrypt.org/docs/staging-environment/
# see https://letsencrypt.org/docs/rate-limits/
# see https://letsencrypt.org/docs/duplicate-certificate-limit/
variable "letsencrypt_server" {
  type        = string
  default     = "https://acme-staging-v02.api.letsencrypt.org/directory"
  description = "The Let's Encrypt server to use"
  validation {
    condition     = contains(["https://acme-staging-v02.api.letsencrypt.org/directory", "https://acme-v02.api.letsencrypt.org/directory"], var.letsencrypt_server)
    error_message = "Unknown value"
  }
}

variable "admin_username" {
  type    = string
  default = "rgl"
}

# NB when you run make terraform-apply this is set from the
#    TF_VAR_admin_ssh_key_data environment variable, which
#    comes from the ~/.ssh/id_rsa.pub file.
variable "admin_ssh_key_data" {
  type      = string
  sensitive = true
}

# see az aks get-versions -l northeurope
# see https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions
variable "k8s_version" {
  type    = string
  default = "1.26.6"
}

output "dns_zone" {
  value = var.dns_zone
}

output "dns_zone_name_servers" {
  value = azurerm_dns_zone.ingress.name_servers
}

output "kube_config" {
  sensitive = true
  value     = azurerm_kubernetes_cluster.example.kube_config_raw
}

output "oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.example.oidc_issuer_url
}

resource "azurerm_resource_group" "example" {
  name     = var.resource_group_name # NB this name must be unique within the Azure subscription.
  location = var.location
  tags     = var.tags
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/dns_zone
resource "azurerm_dns_zone" "ingress" {
  resource_group_name = azurerm_resource_group.example.name
  name                = var.dns_zone
}

# NB this generates a single random number for the resource group.
resource "random_id" "log_analytics" {
  keepers = {
    resource_group = azurerm_resource_group.example.name
  }
  byte_length = 16
}

resource "azurerm_log_analytics_workspace" "example" {
  # NB this name must be globally unique as all the azure accounts share the same namespace.
  # NB this name must be 4-63 characters long.
  name                = "la${random_id.log_analytics.hex}"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "PerGB2018"
  retention_in_days   = 31
}

resource "azurerm_log_analytics_solution" "example" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  workspace_resource_id = azurerm_log_analytics_workspace.example.id
  workspace_name        = azurerm_log_analytics_workspace.example.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster
# see https://learn.microsoft.com/en-us/azure/aks/
resource "azurerm_kubernetes_cluster" "example" {
  name                = "example"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  # NB the default is MC_<resource_group_name>_<location> which is harder to see
  #    in the portal when we sort the resources by name.
  #    e.g. MC_rgl-aks-example_example_northeurope
  # NB this resource group is automatically created and must not already exist.
  node_resource_group = "${azurerm_resource_group.example.name}-node"

  # enable the OIDC Issuer.
  # see https://learn.microsoft.com/en-us/azure/aks/cluster-configuration#oidc-issuer
  # see https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-token-volume-projection
  # see https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#service-account-issuer-discovery
  # see https://techblog.cisco.com/blog/kubernetes-oidc
  oidc_issuer_enabled = true

  # enable workload identity.
  # NB you MUST enable the OIDC Issuer too.
  # see https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview
  # see https://azure.github.io/azure-workload-identity/docs/
  workload_identity_enabled = true

  # NB dns_prefix will be used in the k8s api server public address as defined
  #    by the following pattern:
  #       https://<dns_prefix>-<random>.hcp.<location>.azmk8s.io
  #    for example:
  #       https://example-87d0a6ab.hcp.northeurope.azmk8s.io
  dns_prefix         = "example"
  kubernetes_version = var.k8s_version

  default_node_pool {
    name                 = "default"
    vm_size              = "Standard_D2_v2"
    os_disk_size_gb      = 30
    node_count           = 1
    orchestrator_version = var.k8s_version
  }

  network_profile {
    network_plugin    = "kubenet"
    load_balancer_sku = "standard"
  }

  linux_profile {
    # to ssh into the managed worker nodes see:
    #   https://unofficialism.info/posts/easy-way-ssh-into-aks-cluster-node/
    #   https://github.com/yokawasa/kubectl-plugin-ssh-jump
    #   https://learn.microsoft.com/en-us/azure/aks/node-access
    admin_username = var.admin_username
    ssh_key {
      key_data = var.admin_ssh_key_data
    }
  }

  # see https://learn.microsoft.com/en-us/azure/azure-monitor/containers/container-insights-onboard
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.example.id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = var.tags
}
