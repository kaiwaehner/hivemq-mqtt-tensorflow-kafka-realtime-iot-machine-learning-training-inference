# MQTT Device Simulator

This is the part of the infrastructure which generates the MQTT clients and publishes the sensor data to the MQTT broker.

It uses a Kubernetes extension to run a (very early version) of a MQTT device fleet simulator,
fitted with a plugin (see [here](https://github.com/sbaier1/avro-car-sensor-simulator#build-load-simulator) for more information)
to generate simulated car sensor data. 

Note that at this point the extension is not perfectly idempotent, meaning sometimes you will have to execute the `run` command twice in-case the state on K8s was not cleaned up correctly.

## Quick Start

1. (Optional): Install [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)

2. (Optional): If you don't have a Kubernetes Cluster, set up Docker for Desktop Kubernetes or Minikube

3. Run `run_scenario.sh` (if you use a HiveMQ license) or [run_scenario_evaluation.sh](../test-generator/run_scenario_evaluation.sh) to run the scenario with HiveMQs evaluation license and only 25 cars being simulated instead.

## Installation

You must first install the Kubernetes extension (it should work on any system with a bash shell and `kubectl` installed):

```bash
chmod +x kube-cli.sh
sudo cp kube-cli.sh /usr/bin/kubectl-devsim
```

**Note**: You can also install to `/usr/local/bin` if you wish.

To verify the correct installation, run `kubectl devsim`. This should print the device simulator CLI usage.

## Running the scenario

```bash
kubectl devsim run -s scenario.xml -l car-demo -i sbaier1/device-simulator:avro
```

## Monitoring integration

If you are running the [Prometheus Operator](https://github.com/coreos/prometheus-operator), you can also integrate the scenario tool with your existing Prometheus instances.

To do so, just specify the `--enable-monitoring` flag when running the scenario and the extension will attempt to create a `ServiceMonitor` which will be kept in place and allow Prometheus to pick up all Device Simulator scenarios being executed automatically.

**Note**: If your Prometheus instance(s) are not picking up the `ServiceMonitor` you may also have to adjust your `Prometheus` object's `serviceMonitorNamespaceSelector` field.

The Device Simulator Commander will then create a `Service` which will target all the simulator pods, which Prometheus can then scrape. 

You can create a Grafana dashboard like this:

```bash
kubectl create configmap devsim-dashboard --from-file=devsim.json || true
kubectl label configmap/devsim-dashboard grafana_dashboard=1 || true
```

## Troubleshooting

If you are seeing connection failures on the Grafana dashboard or simply not receiving the PUBLISHes as expected, you can try to figure out what's going wrong on the simulator pods.

To do so, the easiest way is running the scenario with `-L DEBUG` (or alternatively `-L TRACE`). Wait until the agent pods have spawned (wait a bit until the commander will start them).

Now run `kubectl devsim log --label <run-name> -A`. This will show the logs for all pods and therefore all errors and their cause should turn up here.
