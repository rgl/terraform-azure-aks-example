#!/bin/bash
set -euxo pipefail

AZ="$(whereis az | sed -E 's,az: ,,g')"

subscription_id="$("$AZ" account show --query id --output tsv)"

if [ -z "$subscription_id" ]; then
    echo 'run az login before using this'
    exit 1
fi

mkdir -p shared

# A Service Principal is an application within Azure Active Directory whose authentication tokens
# can be used as the client_id, client_secret, and tenant_id.
# NB this appears in the Azure Portal under:
#       Azure Directory | Default Directory | App registrations | All registrations
#    AND in the subscription as a role assigment in the Azure Portal under:
#       Subscriptions | <your subscription> | Access control (IAM) | Role assignments
# NB if you delete the App, the subscription role assignment is NOT deleted (it
#    will appear as "Identity deleted") and you need to manually delete it.
# NB the // in scopes is to make this work under msys2/cygwin (to prevent it
#    from assuming this is a path that needs to be made absolute).
# see https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html
# TODO restrict this to the resource-group instead?
"$AZ" ad sp \
    create-for-rbac \
    --name rgl-aks-example \
    --role Contributor \
    --scopes //subscriptions/$subscription_id \
    >shared/service-principal.json
