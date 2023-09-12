locals {
  external_dns_namespace            = "external-dns"
  external_dns_service_account_name = "external-dns"
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity
resource "azurerm_user_assigned_identity" "external_dns" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "external-dns"
}

# see az identity federated-credential list
# see https://github.com/MicrosoftDocs/azure-docs/issues/100111#issuecomment-1282914138
# see https://azure.github.io/azure-workload-identity/docs/quick-start.html
# see https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity#establish-federated-identity-credential
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential
resource "azurerm_federated_identity_credential" "external_dns" {
  resource_group_name = azurerm_resource_group.example.name
  name                = "external-dns"
  parent_id           = azurerm_user_assigned_identity.external_dns.id
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject             = "system:serviceaccount:${local.external_dns_namespace}:${local.external_dns_service_account_name}"
  audience            = ["api://AzureADTokenExchange"]
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
resource "azurerm_role_assignment" "external_dns" {
  scope                = azurerm_dns_zone.ingress.id
  principal_id         = azurerm_user_assigned_identity.external_dns.principal_id
  role_definition_name = "DNS Zone Contributor"
}

# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace
resource "kubernetes_namespace" "external_dns" {
  metadata {
    name = local.external_dns_namespace
  }
}

# install external-dns.
# see https://artifacthub.io/packages/helm/bitnami/external-dns
# see https://github.com/bitnami/charts/tree/main/bitnami/external-dns
# see https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/azure.md
# see https://github.com/kubernetes-sigs/external-dns/blob/master/docs/initial-design.md
# see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "external_dns" {
  namespace  = local.external_dns_namespace
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "6.25.0" # app version 0.13.6
  values = [yamlencode({
    policy     = "sync"
    txtOwnerId = var.resource_group_name
    sources = [
      "ingress"
    ]
    domainFilters = [
      var.dns_zone
    ]
    provider = "azure"
    podLabels = {
      "azure.workload.identity/use" = "true"
    }
    serviceAccount = {
      name = local.external_dns_service_account_name
      annotations = {
        "azure.workload.identity/client-id" = azurerm_user_assigned_identity.external_dns.client_id
      }
    }
    azure = {
      tenantId                     = data.azurerm_client_config.current.tenant_id
      subscriptionId               = data.azurerm_client_config.current.subscription_id
      resourceGroup                = azurerm_dns_zone.ingress.resource_group_name
      useWorkloadIdentityExtension = true
    }
  })]
}
