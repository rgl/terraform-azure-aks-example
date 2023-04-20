#!/bin/bash
set -euxo pipefail

# install dependencies.
apt-get install -y apt-transport-https make unzip jq xmlstarlet

# install terraform.
# see https://www.terraform.io/downloads
artifact_url=https://releases.hashicorp.com/terraform/1.4.5/terraform_1.4.5_linux_amd64.zip
artifact_sha=ce10e941cd11554b15a189cd00191c05abc20dff865599d361bdb863c5f406a9
artifact_path="/tmp/$(basename $artifact_url)"
wget -qO $artifact_path $artifact_url
if [ "$(sha256sum $artifact_path | awk '{print $1}')" != "$artifact_sha" ]; then
  echo "downloaded $artifact_url failed the checksum verification"
  exit 1
fi
unzip -o $artifact_path -d /usr/local/bin
rm $artifact_path
CHECKPOINT_DISABLE=1 terraform version

# install azure-cli.
# NB execute apt-cache madison azure-cli to known the available versions.
# see https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-linux?pivots=apt&view=azure-cli-latest
echo "deb [arch=amd64] https://packages.microsoft.com/repos/azure-cli/ $(lsb_release -cs) main" \
    | sudo tee /etc/apt/sources.list.d/azure-cli.list
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
sudo apt-get update
sudo apt-get install -y 'azure-cli=2.42.0-*'
az --version

# install kubectl.
# NB execute apt-cache madison kubectl to known the available versions.
# NB even thou we are on ubuntu jammy (22.04) we are using the xenial packages
#    because they are the only available packages and are compatible with bionic.
# see https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-using-native-package-management
kubectl_version='1.25.2-*' # you should use the same version as the one used in your aks cluster.
wget -qO- https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
add-apt-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
apt-get update
apt-get install -y "kubectl=$kubectl_version"
kubectl version --client --output yaml

# download and install.
# see https://github.com/helm/helm/releases
helm_version='3.11.3'
helm_url="https://get.helm.sh/helm-v$helm_version-linux-amd64.tar.gz"
t="$(mktemp -q -d --suffix=.helm)"
wget -qO- "$helm_url" | tar xzf - -C "$t" --strip-components=1 linux-amd64/helm
install "$t/helm" /usr/local/bin/
rm -rf "$t"

# install k9s.
# see https://github.com/derailed/k9s/releases
k9s_version='v0.27.3'
wget -qO- "https://github.com/derailed/k9s/releases/download/$k9s_version/k9s_Linux_amd64.tar.gz" \
  | tar xzf - k9s
install -m 755 k9s /usr/local/bin/
rm k9s
k9s version

# install cmctl.
# see https://github.com/cert-manager/cert-manager/releases
cmctl_version='v1.10.0'
wget -qO- "https://github.com/cert-manager/cert-manager/releases/download/$cmctl_version/cmctl-linux-amd64.tar.gz" \
  | tar xzf - cmctl
install -m 755 cmctl /usr/local/bin/
rm cmctl
cmctl version --client --output yaml
