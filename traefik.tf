# install traefik as the ingress controller.
# see https://artifacthub.io/packages/helm/traefik/traefik
# see https://github.com/traefik/traefik-helm-chart
# see https://github.com/traefik/traefik-helm-chart/blob/master/traefik/values.yaml
# see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "traefik" {
  namespace  = "kube-system"
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  version    = "12.0.2" # app version 2.9.1
  values = [yamlencode({
    # configure the service.
    service = {
      type = "LoadBalancer"
    }
    # configure the ports.
    ports = {
      web = {
        redirectTo = "websecure"
      }
      websecure = {
        tls = {
          enabled = true
        }
      }
    }
    # configure the tls options.
    # see https://doc.traefik.io/traefik/https/tls/#tls-options
    # see https://wiki.mozilla.org/Security/Server_Side_TLS
    # see https://ssl-config.mozilla.org
    tlsOptions = {
      default = {
        sniStrict  = true
        minVersion = "VersionTLS12"
        cipherSuites = [
          "TLS_ECDHE_ECDSA_WITH_CHACHA20_POLY1305_SHA256",
          "TLS_ECDHE_ECDSA_WITH_AES_128_GCM_SHA256",
          "TLS_ECDHE_ECDSA_WITH_AES_256_GCM_SHA384",
        ]
      }
    }
    # publish the traefik service IP address in the Ingress
    # resources.
    providers = {
      kubernetesIngress = {
        publishedService = {
          enabled = true
        }
      }
    }
    # disable the dashboard IngressRoute.
    ingressRoute = {
      dashboard = {
        enabled = false
      }
    }
    # disable the telemetry (this is done by setting globalArguments).
    globalArguments = []
  })]
}
