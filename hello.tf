# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity
resource "azurerm_user_assigned_identity" "hello" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "hello"
}

# see az identity federated-credential list
# see https://github.com/MicrosoftDocs/azure-docs/issues/100111#issuecomment-1282914138
# see https://azure.github.io/azure-workload-identity/docs/quick-start.html
# see https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity#establish-federated-identity-credential
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential
resource "azurerm_federated_identity_credential" "hello" {
  resource_group_name = azurerm_resource_group.example.name
  name                = "hello"
  parent_id           = azurerm_user_assigned_identity.hello.id
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject             = "system:serviceaccount:${kubernetes_service_account_v1.hello.metadata[0].namespace}:${kubernetes_service_account_v1.hello.metadata[0].name}"
  audience            = ["api://AzureADTokenExchange"]
}

# see https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity
# see https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview#service-account-labels-and-annotations
# see https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.26/#serviceaccount-v1-core
# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1
resource "kubernetes_service_account_v1" "hello" {
  metadata {
    namespace = "default"
    name      = "hello"
    annotations = {
      "azure.workload.identity/client-id" = azurerm_user_assigned_identity.hello.client_id
    }
  }
}

# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret
resource "kubernetes_secret" "hello" {
  metadata {
    namespace = "default"
    name      = "hello"
  }
  data = {
    azure_subscription_id = data.azurerm_client_config.current.subscription_id
  }
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
resource "azurerm_role_assignment" "hello_dns_zone_reader" {
  scope                = azurerm_dns_zone.ingress.id
  principal_id         = azurerm_user_assigned_identity.hello.principal_id
  role_definition_name = "Reader"
}
