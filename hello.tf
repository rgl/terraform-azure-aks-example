# TODO use a azurerm_user_assigned_identity instead of a global application once
#      https://github.com/hashicorp/terraform-provider-azuread/issues/900 lands
#      in a release.
# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application
resource "azuread_application" "hello" {
  display_name = "${var.resource_group_name}-hello"
  owners       = [data.azuread_client_config.current.object_id]
}

# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal
resource "azuread_service_principal" "hello" {
  application_id = azuread_application.hello.application_id
  owners         = [data.azuread_client_config.current.object_id]
}

# see az identity federated-credential list
# see https://github.com/MicrosoftDocs/azure-docs/issues/100111#issuecomment-1282914138
# see https://azure.github.io/azure-workload-identity/docs/quick-start.html
# see https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity#establish-federated-identity-credential
# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential
resource "azuread_application_federated_identity_credential" "hello" {
  application_object_id = azuread_application.hello.object_id
  display_name          = azuread_application.hello.display_name
  description           = "k8s"
  issuer                = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject               = "system:serviceaccount:${kubernetes_service_account_v1.hello.metadata[0].namespace}:${kubernetes_service_account_v1.hello.metadata[0].name}"
  audiences             = ["api://AzureADTokenExchange"]
}

# see https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity
# see https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview#service-account-labels-and-annotations
# see https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/
# see https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.24/#serviceaccount-v1-core
# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/service_account_v1
resource "kubernetes_service_account_v1" "hello" {
  metadata {
    namespace = "default"
    name      = "hello"
    annotations = {
      "azure.workload.identity/client-id" = azuread_application.hello.application_id
    }
    labels = {
      "azure.workload.identity/use" = "true"
    }
  }
}
