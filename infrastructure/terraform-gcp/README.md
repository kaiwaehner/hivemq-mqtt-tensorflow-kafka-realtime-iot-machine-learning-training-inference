# GCP K8s with HiveMQ operator

Applying this terraform deployment will create a K8s cluster with the following deployed:

* Tiller
* Prometheus Operator & Prometheus
* metrics-server for Kubernetes metrics in dashboard
* K8s dashboard (use `gcloud config config-helper --format=json | jq -r ‘.credential.access_token’` for login)

It will also set your kubectl context to the gcp cluster automatically. (To undo this, see `kubectl config get-contexts` and switch to your preferred context)

# Requirements

* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
* helm: e.g. `brew install kubernetes-helm`
* [terraform (0.12)](https://www.terraform.io/downloads.html)
* [GCloud CLI](https://cloud.google.com/sdk/docs/quickstart-macos) (run `gcloud init` first)

# Quick Start

1. Ensure account.json is in this folder. You will have to [create a service account](https://cloud.google.com/iam/docs/creating-managing-service-account-keys) on GCP first.

2. Choose a GCP project or create a new one on your cloud console. Terraform will prompt you to specify your project name when applying.

3.
```bash
terraform init
terraform apply
```

# Kubernetes Dashboard

* Run `kubectl proxy &`
* Go to [K8s dashboard](http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/)
* Login using The token from `gcloud config config-helper --format=json | jq -r '.credential.access_token'`

# Grafana Dashboards

* Forward local port to Grafana service: `kubectl port-forward service/prom-grafana 3000:service`
* Go to [localhost:3000](http://localhost:3000) (login: admin, prom-operator)
* Dashboards will be deployed automatically