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
  version    = "11.1.0" # app version 2.9.1
  values = [yamlencode({
    # configure the certificate resolver.
    # see https://doc.traefik.io/traefik/https/acme/
    # see https://doc.traefik.io/traefik/providers/kubernetes-ingress/#letsencrypt-support-with-the-ingress-provider
    certResolvers = {
      letsencrypt = {
        email        = var.letsencrypt_email
        storage      = "/data/acme.json"
        tlsChallenge = true
      }
    }
    # enable persistence.
    # NB this is mainly used for let's encrypt data.
    # NB this is mounted at /data.
    persistence = {
      enabled = true
    }
    deployment = {
      # fix volume permissions.
      # see https://github.com/traefik/traefik/issues/6972
      initContainers = [{
        name  = "volume-permissions"
        image = "busybox:1.34.1"
        command = [
          "sh",
          "-c",
          <<-EOS
          set -euxo pipefail
          if [ -f /data/acme.json ]; then
            chmod 600 /data/acme.json
          fi
          EOS
        ]
        volumeMounts = [{
          name      = "data"
          mountPath = "/data"
        }]
      }]
    }
    # configure the service.
    service = {
      type = "LoadBalancer"
    }
    # configure the ports.
    ports = {
      websecure = {
        tls = {
          enabled      = true
          certResolver = "letsencrypt"
        }
      }
    }
    # configure the tls options.
    # see https://doc.traefik.io/traefik/https/tls/#tls-options
    tlsOptions = {
      default = {
        sniStrict = true
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
    # disable pilot.
    pilot = {
      enabled   = false
      dashboard = false
    }
    # disable the telemetry (this is done by setting globalArguments)
    globalArguments = []
  })]
}
