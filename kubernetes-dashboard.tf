# install the kubernetes dashboard.
# see https://registry.terraform.io/providers/hashicorp/helm/latest/docs/resources/release
# see https://learn.microsoft.com/en-us/azure/aks/
# see https://artifacthub.io/packages/helm/k8s-dashboard/kubernetes-dashboard
resource "helm_release" "kubernetes_dashboard" {
  namespace  = "kube-system"
  name       = "kubernetes-dashboard"
  repository = "https://kubernetes.github.io/dashboard"
  chart      = "kubernetes-dashboard"
  version    = "6.0.7" # app version 2.7.0
}
