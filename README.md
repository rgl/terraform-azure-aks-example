an example azure kubernetes cluster using aks

This will use [terraform](https://www.terraform.io/) to:

* Create an [Azure Kubernetes Service (AKS)](https://learn.microsoft.com/en-us/azure/aks/) Kubernetes instance.
* Create a public [Azure DNS Zone](https://learn.microsoft.com/en-us/azure/dns/dns-overview).
* Use [Traefik](https://traefik.io/) as the Ingress Controller.
* Use Traefik to create [Let's Encrypt](https://letsencrypt.org/) issued certificates using the [ACME TLS-ALPN-01 challenge](https://letsencrypt.org/docs/challenge-types/#tls-alpn-01).
* Use [external-dns](https://github.com/kubernetes-sigs/external-dns) to create the Ingress DNS Resource Records in the Azure DNS Zone.

# Usage (on a Ubuntu Desktop or builder environment)

Install the tools (or launch and enter the builder environment):

```bash
# install the tools.
./provision-tools.sh
# OR launch the builder environment and use the tools inside it.
# NB you must install the ubuntu 22.04 vagrant base box from:
#     https://github.com/rgl/ubuntu-vagrant
time vagrant up builder
vagrant ssh
cd /vagrant
```

Login into azure-cli:

```bash
az login
```

List the subscriptions and select the current one if the default is not OK:

```bash
az account list
az account set --subscription=<id>
az account show
```

Review `main.tf` and at least change the variables:

* `dns_zone`
* `letsencrypt_email`

Initialize terraform:

```bash
make terraform-init
```

Launch the example:

```bash
export TF_VAR_dns_zone='example.com'
export TF_VAR_letsencrypt_email='john.doe@example.com'
make terraform-apply
```

These are the resources that should have been created:

![](resources.png)

Show the DNS Zone nameservers:

```bash
terraform output -json dns_zone_name_servers
```

Using your parent domain DNS Registrar or DNS Hosting provider, delegate the
`dns_zone` DNS Zone to the returned `dns_zone_name_servers` nameservers. For
example, at the parent domain DNS Zone, add:

```plain
example NS ns1-01.azure-dns.com.
example NS ns2-01.azure-dns.net.
example NS ns3-01.azure-dns.org.
example NS ns4-01.azure-dns.info.
```

Verify the delegation:

```bash
dns_zone="$(terraform output -raw dns_zone)"
dns_zone_name_server="$(terraform output -json dns_zone_name_servers | jq -r '.[0]')"
dig ns $dns_zone "@$dns_zone_name_server"
```

Troubleshoot:

```bash
export KUBECONFIG=$PWD/shared/kube.conf
kubectl -n kube-system get deployments/traefik -o yaml
kubectl -n kube-system logs deployments/traefik
traefik_pod="$(kubectl -n kube-system get pods -l app.kubernetes.io/name=traefik -o name)"
kubectl -n kube-system exec "$traefik_pod" -- cat /data/acme.json
kubectl -n kube-system exec -ti "$traefik_pod" -- sh
#kubectl -n kube-system delete "$traefik_pod"
#helm -n kube-system uninstall traefik; kubectl -n kube-system delete pvc traefik
# also see https://traefik.io/blog/how-to-force-update-lets-encrypt-certificates/
```

**NB** Traefik does not seem to retry the letsencrypt requests, this means
you have to manually restart it by deleting the pod (k8s will automatically
create a new instance to replace the deleted one).

See some information about the cluster:

```bash
export KUBECONFIG=$PWD/shared/kube.conf
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -o wide --all-namespaces
kubectl get pvc --all-namespaces
kubectl get storageclass
```

Deploy an example workload:

```bash
export KUBECONFIG=$PWD/shared/kube.conf
mkdir -p tmp && cd tmp

# deploy the workload.
# see https://github.com/rgl/kubernetes-hello
kubernetes_hello_version='v0.0.0.202210042110-test'
wget -qO \
    resources.yml \
    https://raw.githubusercontent.com/rgl/kubernetes-hello/$kubernetes_hello_version/resources.yml
sed -i -E "s,(\s+host:).+,\1 hello.$dns_zone,g" resources.yml
cat >kustomization.yml <<EOF
resources:
  - resources.yml
images:
  - name: ruilopes/kubernetes-hello
    newTag: $kubernetes_hello_version
EOF
kubectl apply --kustomize .
```

Execute an HTTP request to the example workload ingress:

```bash
kubernetes_hello_ingress="$(kubectl get ingress kubernetes-hello -o json)"
kubernetes_hello_host="$(
  jq -r '.spec.rules[0].host' \
    <<<"$kubernetes_hello_ingress")"
kubernetes_hello_ip="$(
  jq -r '.status.loadBalancer.ingress[0].ip' \
    <<<"$kubernetes_hello_ingress")"
curl \
  --resolve "$kubernetes_hello_host:80:$kubernetes_hello_ip" \
  "http://$kubernetes_hello_host"
```

Execute `dig` until the host domain resolves:

```bash
# NB the external-dns controller takes some time to update the dns zone.
dig "$kubernetes_hello_host"
```

Execute an HTTPS request to the example workload ingress:

```bash
# NB the traefik controller takes some time to acquire the TLS certificate. you
#    can force it by deleting the pod like described in the troubleshoot
#    paragraph that is in this document (see above).
curl "https://$kubernetes_hello_host"
```

Test the HTTPS ingress with https://www.ssllabs.com/ssltest/.

You can now use the kubernetes dashboard (as described in this document) to see the deployment progress.

Or wait until the following command has the service external ip address:

```bash
# NB you should see something like:
#        NAME               TYPE           CLUSTER-IP    EXTERNAL-IP    PORT(S)        AGE   SELECTOR
#        kubernetes         ClusterIP      10.0.0.1      <none>         443/TCP        28h   <none>
#        kubernetes-hello   LoadBalancer   10.0.43.178   40.1.2.3       80:32444/TCP   10m   app=kubernetes-hello
kubectl get services -o wide
```

**NB** A Azure Public IP Address is created for each k8s `LoadBalancer` object.

**NB** The Azure Public IP Address is created inside the node resource group (e.g. `rgl-aks-example-node`) and has a name of the form of `kubernetes-<id>` (e.g. `kubernetes-aa1beedb488eb4e588db541f4698d40a`).

You can now access the EXTERNAL-IP with a web browser, e.g., at:

http://40.1.2.3

When you are done with the example, destroy it:

```bash
kubectl delete --kustomize .
cd ..
```

And destroy everything:

```bash
make terraform-destroy
```

## Kubernetes Dashboard

Launch the kubernetes API server proxy in background:

```bash
export KUBECONFIG=$PWD/shared/kube.conf
kubectl proxy &
```

Create the admin user and save its token:

```bash
# create the admin user for use in the kubernetes-dashboard.
# see https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md
# see https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/README.md
# see https://kubernetes.io/docs/concepts/configuration/secret/#service-account-token-secrets
kubectl apply -n kube-system -f - <<'EOF'
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
---
apiVersion: v1
kind: Secret
type: kubernetes.io/service-account-token
metadata:
  name: admin
  annotations:
    kubernetes.io/service-account.name: admin
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: admin
    namespace: kube-system
EOF
# save the admin token.
install -m 600 /dev/null shared/kube-admin-token.txt
kubectl -n kube-system get secret admin -o json \
  | jq -r .data.token \
  | base64 --decode \
  >shared/kube-admin-token.txt
```

Then access the kubernetes dashboard at:

  http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:https/proxy/

Then select `Token` and use the contents of `shared/kube-admin-token.txt` as the token.

Alternatively you could [assign the cluster-admin role to the kubernetes-dashboard service account](https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard), but by creating an account for you, you only grant it that access when you are using the dashboard.

# Reference

* https://learn.microsoft.com/en-us/azure/aks/
* https://learn.microsoft.com/en-us/azure/developer/terraform/create-k8s-cluster-with-tf-and-aks
* https://azure.microsoft.com/en-us/pricing/details/monitor/
* https://github.com/terraform-providers/terraform-provider-azurerm/tree/master/examples/kubernetes
* https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard
* https://learn.microsoft.com/en-us/azure/aks/internal-lb
