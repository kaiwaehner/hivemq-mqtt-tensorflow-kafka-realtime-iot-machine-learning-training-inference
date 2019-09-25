# HiveMQ on Kubernetes

This piece of infrastructure will deploy HiveMQ in an ephemeral configuration (no stateful set -> no persistent volume claims).

You will need to deploy a license with at least 100k connections to your cluster in order to deploy the HiveMQ cluster, like such:

```bash
kubectl create -n hivemq configmap hivemq-license --from-file=my-license.lic || true
```

Then you can deploy HiveMQ by running `./setup.sh`

Alternatively, you can use [setup_evaluation.sh](setup_evaluation.sh) and [run_scenario_evaluation.sh](../test-generator/run_scenario_evaluation.sh) to run the scenario with HiveMQs evaluation license and only 25 cars being simulated instead.

# Monitoring

Grafana Dashboards will be deployed using the Prometheus Operator, see the [Terraform script](../terraform-gcp)
