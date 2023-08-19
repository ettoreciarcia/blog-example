.PHONY: init
init:
	terraform init
.PHONY: show
show:
	terraform show
.PHONY: plan
plan:
	terraform fmt && terraform validate && terraform plan -out=terraform.plan
.PHONY: apply
apply:
	terraform apply terraform.plan

