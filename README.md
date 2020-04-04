an example azure kubernetes cluster using aks

# Usage (on a Ubuntu Desktop or builder environment)

Install the tools (or launch and enter the builder environment):

```bash
# install the tools.
./provision-tools.sh
# OR launch the builder environment and use the tools inside it.
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

Review `main.tf` and maybe change the `location` variable.

Initialize terraform:

```bash
make terraform-init
```

Launch the example:

```bash
make terraform-apply
```

These are the resources that should have been created:

![](resources.png)

See some information about the cluster:

```bash
export KUBECONFIG=$PWD/shared/kube.conf
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -o wide --all-namespaces
kubectl get storageclass
```

Deploy an example workload:

```bash
export KUBECONFIG=$PWD/shared/kube.conf
mkdir -p tmp && cd tmp

# deploy the workload.
kubernetes_hello_version='v0.0.0.202004041457-test'
wget -qO \
    resources.yml \
    https://raw.githubusercontent.com/rgl/kubernetes-hello/$kubernetes_hello_version/resources.yml
cat >kustomization.yml <<EOF
resources:
  - resources.yml
images:
  - name: ruilopes/kubernetes-hello
    newTag: $kubernetes_hello_version
EOF
kubectl apply --kustomize .
```

You can now use the kubernetes dashboard (as described in this document) to see the deployment progress.

Or wait until the following command return the service external ip address:

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
```

## Kubernetes Dashboard

Launch the kubernetes API server proxy in background:

```bash
export KUBECONFIG=$PWD/shared/kube.conf
kubectl proxy &
```

Create the admin user and save its token:

```bash
# create the admin user.
# see https://github.com/kubernetes/dashboard/wiki/Creating-sample-user
# see https://github.com/kubernetes/dashboard/wiki/Access-control
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin
  namespace: kube-system
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
kubectl \
  -n kube-system \
  get \
  secret \
  $(kubectl -n kube-system get secret | grep admin-token- | awk '{print $1}') \
  -o json | jq -j .data.token | base64 --decode \
  >shared/kube-admin-token.txt
```

Then access the kubernetes dashboard at:

    http://localhost:8001/api/v1/namespaces/kube-system/services/https:kubernetes-dashboard:/proxy/

Then select `Token` and use the contents of `shared/kube-admin-token.txt` as the token.

Alternatively you could [assign the cluster-admin role to the kubernetes-dashboard service account](https://docs.microsoft.com/en-us/azure/aks/kubernetes-dashboard), but by creating an account for you, you only grant it that access when you are using the dashboard.

# Reference

* https://docs.microsoft.com/en-us/azure/aks/
* https://docs.microsoft.com/en-us/azure/terraform/terraform-create-k8s-cluster-with-tf-and-aks
* https://azure.microsoft.com/en-us/pricing/details/monitor/
* https://github.com/terraform-providers/terraform-provider-azurerm/tree/master/examples/kubernetes
* https://docs.microsoft.com/en-us/azure/aks/load-balancer-standard
* https://docs.microsoft.com/en-us/azure/aks/internal-lb
