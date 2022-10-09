#!/bin/bash
set -euo pipefail

export KUBECONFIG="$(dirname "$0")/../shared/kube.conf"

dns_zone="$(terraform output -raw dns_zone)"

sed -E "s,(\.example\.com),.$dns_zone,g" "$(dirname "$0")/resources.yml" \
  | kubectl delete -f -
