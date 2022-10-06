# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application
resource "azuread_application" "cert_manager" {
  display_name = "${var.resource_group_name}-cert-manager"
  owners       = [data.azuread_client_config.current.object_id]
}

# see https://registry.terraform.io/providers/hashicorp/time/latest/docs/resources/rotating
resource "time_rotating" "cert_manager" {
  rotation_days = 7
}

# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_password
resource "azuread_application_password" "cert_manager" {
  application_object_id = azuread_application.cert_manager.object_id
  rotate_when_changed = {
    rotation = time_rotating.cert_manager.id
  }
}

# see https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal
resource "azuread_service_principal" "cert_manager" {
  application_id               = azuread_application.cert_manager.application_id
  owners                       = [data.azuread_client_config.current.object_id]
  app_role_assignment_required = false
}

# see https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment
resource "azurerm_role_assignment" "cert_manager" {
  scope                = azurerm_dns_zone.ingress.id
  principal_id         = azuread_service_principal.cert_manager.id
  role_definition_name = "DNS Zone Contributor"
}

# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/namespace
resource "kubernetes_namespace" "cert_manager" {
  metadata {
    name = "cert-manager"
  }
}

# see https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs/resources/secret
resource "kubernetes_secret" "cert_manager_azure_dns" {
  metadata {
    namespace = kubernetes_namespace.cert_manager.metadata[0].name
    name      = "cert-manager-azure-dns"
  }
  data = {
    client_secret = azuread_application_password.external_dns.value
  }
}

# install cert-manager.
# NB YOU CANNOT INSTALL MULTIPLE INSTANCES OF CERT-MANAGER IN A CLUSTER.
# see https://artifacthub.io/packages/helm/cert-manager/cert-manager
# see https://github.com/cert-manager/cert-manager/tree/master/deploy/charts/cert-manager
# see https://cert-manager.io/docs/installation/supported-releases/
# see https://cert-manager.io/docs/configuration/acme/
# see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "cert_manager" {
  namespace  = kubernetes_namespace.cert_manager.metadata[0].name
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "1.9.1" # app version 1.9.1
  values = [yamlencode({
    # NB installCRDs is generally not recommended, BUT since this
    #    is a development cluster we YOLO it.
    installCRDs = true
  })]
}

# create the ingress cluster issuer.
# see https://cert-manager.io/docs/configuration/acme/
# see https://cert-manager.io/docs/configuration/acme/dns01/
# see https://cert-manager.io/docs/configuration/acme/dns01/azuredns/#service-principal
resource "kubectl_manifest" "cert_manager_ingress" {
  depends_on = [
    helm_release.cert_manager
  ]
  yaml_body = yamlencode({
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      namespace = kubernetes_namespace.cert_manager.metadata[0].name
      name      = "ingress"
    }
    spec = {
      acme = {
        server = "https://acme-v02.api.letsencrypt.org/directory"
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
              tenantID          = data.azurerm_client_config.current.tenant_id
              subscriptionID    = data.azurerm_client_config.current.subscription_id
              resourceGroupName = azurerm_dns_zone.ingress.resource_group_name
              clientID          = azuread_service_principal.external_dns.application_id
              clientSecretSecretRef = {
                name = kubernetes_secret.cert_manager_azure_dns.metadata[0].name
                key  = "client_secret"
              }
              hostedZoneName = var.dns_zone
            }
          }
        }]
      }
    }
  })
}
