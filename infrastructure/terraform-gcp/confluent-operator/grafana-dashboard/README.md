# Monitoring

All Confluent Platform (CP) components deployed through the Confluent Operator expose metrics that can be scraped by
Prometheus. This folder contains an example Grafana metrics dashboard for all components except Confluent Control Center. For
production environments, you may need to modify the example dashboard to meet your needs. Follow best practices for
managing your Prometheus and Grafana deployments. Completing the following instructions will help you understand what the example
dashboard can display for you.

These instructions were last verified with:

* Helm v3.0.2
* Prometheus Helm chart v9.7.2 (app version 2.13.1)
* Grafana Helm chart v4.2.2 (app verison 6.5.2)

## Install Prometheus

    helm install demo-test stable/prometheus \
     --set alertmanager.persistentVolume.enabled=false \
     --set server.persistentVolume.enabled=false \
     --namespace default

## Install Grafana

    helm install grafana stable/grafana --namespace default
    
## Open Grafana in your Browser
    
Start port-forwarding so you can access Grafana in your browser with a `localhost` address:

     kubectl port-forward \
      $(kubectl get pods -n default -l app=grafana,release=grafana -o jsonpath={.items[0].metadata.name}) \
      3000 \
      --namespace default

Get your 'admin' user password:

    kubectl get secret --namespace default grafana -o jsonpath="{.data.admin-password}" | base64 --decode
    
Visit http://localhost:3000 in your browser, and login as the `admin` user with the decoded password.

## Configure Grafana with a Prometheus Data Source

Follow the in-browser instructions to configure a Prometheus data source for Grafana, or consult the
[online documentation](https://prometheus.io/docs/visualization/grafana/#creating-a-prometheus-data-source). You will be asked
to provide a URL. Enter the URL as shown below:

    http://demo-test-prometheus-server.default.svc.cluster.local

Click "Save & Test". You should see a green alert at the bottom of the page saying "Data source
is working".
   
## Import Grafana Dashboard Configuration

Follow the in-browser instructions to import a dashboard JSON configuration, or consult the
[online documentation](https://grafana.com/docs/grafana/latest/reference/export_import/#importing-a-dashboard). Select the
`grafana-dashboard.json` file located in this folder, and then select the previously-configured Prometheus data source.

## Explore Grafana Dashboard

The following five CP component rows should be displayed:

* Confluent Kafka (16 panels)
* Confluent Kafka Connect/Replicator (9 panels)
* Confluent KSQL Server (6 panels)
* Confluent Schema Registry (4 panels)
* Confluent Zookeeper (10 panels)

You can expand these rows to see a variety of metrics for each CP component.
