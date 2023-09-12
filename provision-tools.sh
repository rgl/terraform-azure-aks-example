#!/bin/bash
set -euxo pipefail

# install dependencies.
apt-get install -y apt-transport-https make unzip jq xmlstarlet

# install terraform.
# see https://www.terraform.io/downloads
artifact_url=https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
artifact_path="/tmp/$(basename $artifact_url)"
wget -qO $artifact_path $artifact_url
unzip -o $artifact_path -d /usr/local/bin
rm $artifact_path
CHECKPOINT_DISABLE=1 terraform version

# install azure-cli.
# NB execute apt-cache madison azure-cli to known the available versions.
# see https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt&view=azure-cli-latest
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor >/etc/apt/keyrings/packages.microsoft.com.gpg
echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/packages.microsoft.com.gpg] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
  >/etc/apt/sources.list.d/azure-cli.list
apt-get update
apt-get install -y 'azure-cli=2.52.0-*'
az --version

# install kubectl.
# NB execute apt-cache madison kubectl to known the available versions.
# NB even thou we are on ubuntu jammy (22.04) we are using the xenial packages
#    because they are the only available packages and are compatible with bionic.
# see https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-using-native-package-management
kubectl_version='1.26.6-*' # you should use the same version as the one used in your aks cluster.
wget -qO /etc/apt/keyrings/packages.cloud.google.com.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/packages.cloud.google.com.gpg] http://apt.kubernetes.io/ kubernetes-xenial main" \
  >/etc/apt/sources.list.d/kubernetes.list
apt-get update
apt-get install -y "kubectl=$kubectl_version"
kubectl version --client --output yaml

# download and install.
# see https://github.com/helm/helm/releases
helm_version='3.12.3'
helm_url="https://get.helm.sh/helm-v$helm_version-linux-amd64.tar.gz"
t="$(mktemp -q -d --suffix=.helm)"
wget -qO- "$helm_url" | tar xzf - -C "$t" --strip-components=1 linux-amd64/helm
install "$t/helm" /usr/local/bin/
rm -rf "$t"

# install k9s.
# see https://github.com/derailed/k9s/releases
k9s_version='v0.27.4'
wget -qO- "https://github.com/derailed/k9s/releases/download/$k9s_version/k9s_Linux_amd64.tar.gz" \
  | tar xzf - k9s
install -m 755 k9s /usr/local/bin/
rm k9s
k9s version

# install cmctl.
# see https://github.com/cert-manager/cert-manager/releases
cmctl_version='v1.12.4'
wget -qO- "https://github.com/cert-manager/cert-manager/releases/download/$cmctl_version/cmctl-linux-amd64.tar.gz" \
  | tar xzf - cmctl
install -m 755 cmctl /usr/local/bin/
rm cmctl
cmctl version --client --output yaml
