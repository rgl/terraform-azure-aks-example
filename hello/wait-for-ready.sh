#!/bin/bash
set -euo pipefail

# NB the external-dns controller takes some time to update the dns zone.
# NB the cert-manager controller takes some time to create the certificate.
export KUBECONFIG="$(dirname "$0")/../shared/kube.conf"

# wait for domain to resolve.
hello_ingress="$(kubectl get ingress hello -o json)"
hello_host="$(jq -r '.spec.rules[0].host' <<<"$hello_ingress")"
hello_ip="$(jq -r '.status.loadBalancer.ingress[0].ip' <<<"$hello_ingress")"
echo "Waiting for the $hello_host domain to resolve..."
while true; do
  if [ -n "$hello_ip" ] && [ "$(dig +short "$hello_host")" == "$hello_ip" ]; then
    break
  fi
  sleep 15
done

# wait for certificate to be ready.
echo "Waiting for the certificate to be ready..."
while ! kubectl wait --timeout=3m --for=condition=Ready certificate/hello; do
  echo '#### certificate not ready ####'
  kubectl get event --field-selector=involvedObject.kind=Certificate,involvedObject.name=hello
done
echo "Certificate is ready."
cmctl status certificate hello

# wait for the endpoint to be ready.
echo "Waiting for the https://$hello_host endpoint to be ready..."
while true; do
  if wget -q --spider "https://$hello_host"; then
    echo "The hello endpoint is ready at https://$hello_host"
    break
  fi
  if wget -q --spider "https://$hello_host" --ca-certificate "$(dirname "$0")/../shared/letsencrypt-staging-ca-certificates.pem"; then
    echo "The hello STAGING endpoint is ready at https://$hello_host"
    break
  fi
  sleep 15
done
