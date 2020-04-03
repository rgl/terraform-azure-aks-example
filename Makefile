all: terraform-apply

terraform-init:
	CHECKPOINT_DISABLE=1 \
	TF_LOG=TRACE \
	TF_LOG_PATH=terraform.log \
	terraform init
	CHECKPOINT_DISABLE=1 \
	terraform -v

terraform-apply: shared/service-principal.json ~/.ssh/id_rsa
	CHECKPOINT_DISABLE=1 \
	TF_LOG=TRACE \
	TF_LOG_PATH=terraform.log \
	TF_VAR_admin_ssh_key_data="$(shell cat ~/.ssh/id_rsa.pub)" \
	TF_VAR_service_principal_client_id="$(shell jq -r .appId shared/service-principal.json)" \
	TF_VAR_service_principal_client_secret="$(shell jq -r .password shared/service-principal.json)" \
	time terraform apply
	terraform output kube_config >shared/kube.conf
	KUBECONFIG=shared/kube.conf kubectl cluster-info
	KUBECONFIG=shared/kube.conf kubectl get nodes -o wide
	KUBECONFIG=shared/kube.conf kubectl get pods -o wide --all-namespaces

terraform-destroy:
	CHECKPOINT_DISABLE=1 \
	TF_LOG=TRACE \
	TF_LOG_PATH=terraform.log \
	TF_VAR_admin_ssh_key_data="$(shell cat ~/.ssh/id_rsa.pub)" \
	TF_VAR_service_principal_client_id="$(shell jq -r .appId shared/service-principal.json)" \
	TF_VAR_service_principal_client_secret="$(shell jq -r .password shared/service-principal.json)" \
	time terraform destroy

shared/service-principal.json:
	./provision-service-principal.sh

~/.ssh/id_rsa:
	ssh-keygen -f $@ -t rsa -b 2048 -C "$$USER@$$(hostname --fqdn)" -N ''

.PHONY: terraform-init terraform-apply terraform-destroy
