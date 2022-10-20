all: terraform-apply

terraform-init:
	CHECKPOINT_DISABLE=1 \
	TF_LOG=TRACE \
	TF_LOG_PATH=terraform.log \
	terraform init
	CHECKPOINT_DISABLE=1 \
	terraform -v

terraform-apply: shared/letsencrypt-staging-ca-certificates.pem ~/.ssh/id_rsa
	CHECKPOINT_DISABLE=1 \
	TF_LOG=TRACE \
	TF_LOG_PATH=terraform.log \
	TF_VAR_admin_ssh_key_data="$(shell cat ~/.ssh/id_rsa.pub)" \
	time terraform apply
	install -m 600 /dev/null shared/kube.conf
	terraform output -raw kube_config >shared/kube.conf
	KUBECONFIG=shared/kube.conf kubectl cluster-info
	KUBECONFIG=shared/kube.conf kubectl get nodes -o wide

terraform-destroy:
	CHECKPOINT_DISABLE=1 \
	TF_LOG=TRACE \
	TF_LOG_PATH=terraform.log \
	TF_VAR_admin_ssh_key_data="$(shell cat ~/.ssh/id_rsa.pub)" \
	time terraform destroy

# see https://letsencrypt.org/docs/staging-environment/
shared/letsencrypt-staging-ca-certificates.pem:
	install -d "$$(dirname "$@")"
	wget -qO $@ https://letsencrypt.org/certs/staging/letsencrypt-stg-root-x2.pem

~/.ssh/id_rsa:
	ssh-keygen -f $@ -t rsa -b 2048 -C "$$USER@$$(hostname --fqdn)" -N ''

clean:
	rm -rf shared tmp *.log

.PHONY: all clean terraform-init terraform-apply terraform-destroy
