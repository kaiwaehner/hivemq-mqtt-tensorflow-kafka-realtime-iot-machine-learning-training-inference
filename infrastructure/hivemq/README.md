# HiveMQ on Kubernetes

This piece of infrastructure will deploy HiveMQ in an ephemeral configuration (no stateful set -> no persistent volume claims).

You will need to deploy a license with at least 100k connections to your cluster in order to deploy the HiveMQ cluster, like such:

```bash
kubectl create -n hivemq configmap hivemq-license --from-file=my-license.lic || true
```

Then you can deploy HiveMQ by running `./setup.sh`