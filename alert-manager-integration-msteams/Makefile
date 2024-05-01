init-cluster:
	kind create cluster --config kind-config.yaml

delete-cluster:
	kind delete clusters poc-am-teams

init-prometheus:
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && \
	kubectl create ns monitoring && \
	helm repo update && \
	helm install monitoring-stack prometheus-community/kube-prometheus-stack -n monitoring

init-prom2teams:
ifndef WEBHOOK_URL
	$(error WEBHOOK_URL not defined!)
endif
	git clone https://github.com/idealista/prom2teams.git && helm install prom2teams $(PWD)/prom2teams/helm -n monitoring --set prom2teams.connector=$(WEBHOOK_URL)

delete-prom2teams:
	helm uninstall prom2teams -n monitoring

setup-everything: init-cluster init-prometheus init-prom2teams
