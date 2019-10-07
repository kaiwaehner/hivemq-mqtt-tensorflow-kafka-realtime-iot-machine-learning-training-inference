# HiveMQ on Kubernetes

This piece of infrastructure will deploy HiveMQ in an ephemeral configuration (no stateful set -> no persistent volume claims).

## Deployment with license for 100K connections
You will need to deploy a license with at least 100k connections to your cluster in order to deploy the HiveMQ cluster, like such:

```bash
kubectl create -n hivemq configmap hivemq-license --from-file=my-license.lic || true
```

Then you can deploy HiveMQ by running `./setup.sh`

##  Deployment with open source version (limited to 25 cars)
Alternatively, you can use [setup_evaluation.sh](setup_evaluation.sh).

# Monitoring

Grafana Dashboards will be deployed using the Prometheus Operator, see the [Terraform script](../terraform-gcp) which sets up the GCP Kubernetes infrastructure.
