# install nginx as the ingress controller.
# see https://artifacthub.io/packages/helm/ingress-nginx/ingress-nginx
# see https://github.com/kubernetes/ingress-nginx
# see https://github.com/kubernetes/ingress-nginx/blob/main/charts/ingress-nginx/values.yaml
# see https://learn.microsoft.com/en-us/azure/aks/ingress-basic?tabs=azure-cli
# see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
resource "helm_release" "ingress_nginx" {
  namespace  = "kube-system"
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.0" # app version 1.9.0
  values = [yamlencode({
    controller = {
      ingressClassResource = {
        default = true
      }
      service = {
        annotations = {
          "service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path" = "/healthz"
        }
      }
    }
  })]
}
