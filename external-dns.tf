# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application
resource "azuread_application" "external_dns" {
  display_name = "${var.resource_group_name}-external-dns"
  owners       = [data.azuread_client_config.current.object_id]
}

# see https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating
resource "time_rotating" "external_dns" {
  rotation_days = 7
}

# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password
resource "azuread_application_password" "external_dns" {
  application_object_id = azuread_application.external_dns.object_id
  rotate_when_changed = {
    rotation = time_rotating.external_dns.id
  }
}

# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal
resource "azuread_service_principal" "external_dns" {
  application_id               = azuread_application.external_dns.application_id
  owners                       = [data.azuread_client_config.current.object_id]
  app_role_assignment_required = false
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
resource "azurerm_role_assignment" "external_dns" {
  scope                = azurerm_dns_zone.ingress.id
  principal_id         = azuread_service_principal.external_dns.id
  role_definition_name = "DNS Zone Contributor"
}

# install external-dns.
# see https://artifacthub.io/packages/helm/bitnami/external-dns
# see https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/azure.md
# see https://github.com/kubernetes-sigs/external-dns/blob/master/docs/initial-design.md
resource "helm_release" "external_dns" {
  namespace  = "kube-system"
  name       = "external-dns"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "external-dns"
  version    = "6.10.2" # app version 0.12.2
  values = [yamlencode({
    sources = [
      "ingress"
    ]
    txtOwnerId = "k8s"
    domainFilters = [
      var.dns_zone
    ]
    provider = "azure"
    azure = {
      tenantId        = data.azurerm_client_config.current.tenant_id
      subscriptionId  = data.azurerm_client_config.current.subscription_id
      resourceGroup   = azurerm_dns_zone.ingress.resource_group_name
      aadClientId     = azuread_service_principal.external_dns.application_id
      aadClientSecret = azuread_application_password.external_dns.value
    }
  })]
}
