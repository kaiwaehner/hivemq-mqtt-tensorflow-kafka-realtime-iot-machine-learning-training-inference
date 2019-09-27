# GCP K8s with HiveMQ operator

Applying this terraform deployment will create a K8s cluster with the following deployed:

* Tiller
* Prometheus Operator & Prometheus
* metrics-server for Kubernetes metrics in dashboard
* K8s dashboard (use `gcloud config config-helper --format=json | jq -r ‘.credential.access_token’` for login)

It will also set your kubectl context to the gcp cluster automatically. (To undo this, see `kubectl config get-contexts` and switch to your preferred context)

# Requirements
The following components are required:

* jq: e.g. 'brew install jq'
* [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/): e.g. brew install kubernetes-cli (tested with 1.16.0)
* helm: e.g. `brew install kubernetes-helm` (tested with 2.14.3)
* [terraform (0.12)](https://www.terraform.io/downloads.html): e.g. brew install terraform
* [GCloud CLI](https://cloud.google.com/sdk/docs/quickstart-macos) (run `gcloud init` first)

The setup is tested on Mac OS X.

Make sure to have updated versions, e.g. an older version of helm did not work.

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
* Login to K8s dashboard using The token from `gcloud config config-helper --format=json | jq -r '.credential.access_token'`

# Grafana Dashboards

* Forward local port to Grafana service: `kubectl port-forward service/prom-grafana 3000:service`
* Go to [localhost:3000](http://localhost:3000) (login: admin, prom-operator)
* Dashboards will be deployed automatically (if they are not visible, bounce the deployment by deleting the current Grafana pod. It will reload the ConfigMaps after it restarts.)

# Destroy Infrastructure

* Run 'terraform destroy' to stop and remove the created Kubernetes infrastructure