locals {
  cert_manager_namespace            = "cert-manager"
  cert_manager_service_account_name = "cert-manager"
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity
resource "azurerm_user_assigned_identity" "cert_manager" {
  resource_group_name = azurerm_resource_group.example.name
  location            = azurerm_resource_group.example.location
  name                = "cert-manager"
}

# see az identity federated-credential list
# see https://github.com/MicrosoftDocs/azure-docs/issues/100111#issuecomment-1282914138
# see https://azure.github.io/azure-workload-identity/docs/quick-start.html
# see https://learn.microsoft.com/en-us/azure/aks/learn/tutorial-kubernetes-workload-identity#establish-federated-identity-credential
# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/federated_identity_credential
resource "azurerm_federated_identity_credential" "cert_manager" {
  resource_group_name = azurerm_resource_group.example.name
  name                = "cert-manager"
  parent_id           = azurerm_user_assigned_identity.cert_manager.id
  issuer              = azurerm_kubernetes_cluster.example.oidc_issuer_url
  subject             = "system:serviceaccount:${local.cert_manager_namespace}:${local.cert_manager_service_account_name}"
  audience            = ["api://AzureADTokenExchange"]
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
resource "azurerm_role_assignment" "cert_manager" {
  scope                = azurerm_dns_zone.ingress.id
  principal_id         = azurerm_user_assigned_identity.cert_manager.principal_id
  role_definition_name = "DNS Zone Contributor"
}

# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = local.cert_manager_namespace
  }
}

# install cert-manager.
# NB YOU CANNOT INSTALL MULTIPLE INSTANCES OF CERT-MANAGER IN A CLUSTER.
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager
# see https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager
# see https://cert-manager.io/docs/installation/supported-releases/
# see https://cert-manager.io/docs/configuration/acme/
# see https://cert-manager.io/docs/tutorials/getting-started-aks-letsencrypt/
# see https://letsencrypt.org/docs/rate-limits/
# see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "cert_manager" {
  namespace  = local.cert_manager_namespace
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.11.1" # app version 1.11.1
  values = [yamlencode({
    # NB installCRDs is generally not recommended, BUT since this
    #    is a development cluster we YOLO it.
    installCRDs = true
    podLabels = {
      "azure.workload.identity/use" = "true"
    }
    serviceAccount = {
      name = local.cert_manager_service_account_name
    }
  })]
}

# create the ingress cluster issuer.
# see https://cert-manager.io/docs/configuration/acme/
# see https://cert-manager.io/docs/configuration/acme/dns01/
# see https://cert-manager.io/docs/configuration/acme/dns01/azuredns/#managed-identity-using-aad-workload-identity
# see https://letsencrypt.org/docs/staging-environment/
# see https://letsencrypt.org/docs/duplicate-certificate-limit/
resource "kubectl_manifest" "cert_manager_ingress" {
  depends_on = [
    helm_release.cert_manager
  ]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      namespace = local.cert_manager_namespace
      name      = "ingress"
    }
    spec = {
      acme = {
        server = var.letsencrypt_server
        email  = var.letsencrypt_email
        privateKeySecretRef = {
          name = "cert-manager-ingress-letsencrypt"
        }
        solvers = [{
          selector = {
            dnsZones = [
              var.dns_zone
            ]
          }
          dns01 = {
            azureDNS = {
              subscriptionID    = data.azurerm_client_config.current.subscription_id
              resourceGroupName = azurerm_dns_zone.ingress.resource_group_name
              hostedZoneName    = var.dns_zone
              managedIdentity = {
                clientID = azurerm_user_assigned_identity.cert_manager.client_id
              }
            }
          }
        }]
      }
    }
  })
}
