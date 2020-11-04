{{/* vim: set filetype=mustache: */}}
{{/*
Expand the name of the chart.
*/}}
{{- define "confluent-operator.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create a default fully qualified app name.
We truncate at 63 chars because some Kubernetes name fields are limited to this (by the DNS naming spec).
If release name contains chart name it will be used as a full name.
*/}}
{{- define "confluent-operator.fullname" -}}
{{- if .Values.fullnameOverride -}}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- $name := default .Chart.Name .Values.nameOverride -}}
{{- if contains $name .Release.Name -}}
{{- .Release.Name | trunc 63 | trimSuffix "-" -}}
{{- else -}}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" -}}
{{- end -}}
{{- end -}}
{{- end -}}

{{/*
Create chart name and version as used by the chart label.
*/}}
{{- define "confluent-operator.chart" -}}
{{- printf "%s-%s" $.Chart.Name $.Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" -}}
{{- end -}}

{{/*
Create private docker-registry secret
*/}}
{{- define "confluent-operator.imagePullSecret" }}
{{- printf "{\"auths\": {\"%s\": {\"auth\": \"%s\"}}}" .Values.global.provider.registry.fqdn (printf "%s:%s" .Values.global.provider.registry.credential.username .Values.global.provider.registry.credential.password | b64enc) }}
{{- end -}}

{{/*
Create APIkeys for Kafka Cluster
*/}}
{{- define "confluent-operator.apikeys" }}
{{- $_ := required "sasl plain username" .Values.global.sasl.plain.username }}
{{- $_ := required "sasl plain password" .Values.global.sasl.plain.password }}
{{- printf "{ \"keys\": { \"%s\": { \"sasl_mechanism\": \"PLAIN\", \"hashed_secret\": \"%s\", \"hash_function\": \"none\", \"logical_cluster_id\": \"%s\", \"user_id\": \"%s\", \"service_account\": false}}}" .Values.global.sasl.plain.username .Values.global.sasl.plain.password .Release.Namespace .Values.global.sasl.plain.username }}
{{- end }}

{{/*
Distribution of pods placement based on zones
*/}}
{{- define "confluent-operator.pod-distribution" }}
{{- $result := dict }}
{{- $zoneCounts := len .Values.global.provider.kubernetes.deployment.zones }}
{{- $zonesList := .Values.global.provider.kubernetes.deployment.zones }}
{{- range $i :=  until ($.replicas | int) }}
    {{- $podName := join "-" (list $.name $i) }}
    {{- $pointer :=  mod $i $zoneCounts }}
    {{- $zoneName := index $zonesList $pointer }} 
    {{- if hasKey $result $zoneName }}
    {{- $ignore :=  dict "pods" (append (index (index $result $zoneName) "pods") $podName) | set $result $zoneName  }}
    {{- else }}
    {{- $ignore := set $result $zoneName (dict "pods" (list $podName)) }}
    {{- end }}
{{- end }}
{{ $result | toYaml | trim | indent 6 }}
{{- end }}

{{/*
  Find replication count based on the size of Kafka Cluster
*/}}
{{- define "confluent-operator.replication_count" }}
{{- $replicas := $.kreplicas | int }}
{{- $count := 1 }}
{{- if lt $replicas 3 }}
{{- $count := 1 }}
{{- printf "%d" $count }}
{{- else }}
{{- $count := 3 }}
{{- printf "%d" $count }}
{{- end -}}
{{- end -}}

{{/*
  Find ISR count based on the size of Kafka Cluster
*/}}
{{- define "confluent-operator.isr_count" }}
{{- $replicas := $.kreplicas | int }}
{{- $count := 1 }}
{{- if lt $replicas 3 }}
{{- $count := 1 }}
{{- printf "%d" $count }}
{{- else }}
{{- $count := 2 }}
{{- printf "%d" $count }}
{{- end -}}
{{- end -}}

{{/* Generate components labels */}}
{{- define "confluent-operator.labels" }}
  labels:
    component: {{ template "confluent-operator.name" $ }}
{{- end }}

{{/* Generate pod annotations for PSC */}}
{{- define "confluent-operator.annotations" }}
config.value.checksum: {{ include "confluent-operator.generate-sha256sum" .  | trim }}
prometheus.io/scrape: "true"
prometheus.io/port: "7778"
{{- if .Values.podAnnotations }}
{{- range $key, $value := .Values.podAnnotations }}
{{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/* Generate pod annotations for CR */}}
{{- define "confluent-operator.cr-annotations" }}
{{- if .Values.podAnnotations }}
podAnnotations:
{{- range $key, $value := .Values.podAnnotations }}
  {{ $key }}: {{ $value | quote }}
{{- end }}
{{- end }}
{{- end }}

{{/* Generate PSC finalizers */}}
{{- define "confluent-operator.finalizers" }}
  finalizers:
  - physicalstatefulcluster.core.confluent.cloud
  - physicalstatefulcluster.proxy.confluent.cloud
{{- end }}

{{/* Generate component name */}}
{{- define "confluent-operator.component-name" }}
  name: {{ .Values.name }}
{{- end }}

{{/* Generate component namespace */}}
{{- define "confluent-operator.namespace" }}
  namespace: {{ .Release.Namespace }}
{{- end }}

{{/* configure to enable/disable hostport */}}
{{- define "confluent-operator.hostPort" }}
{{- if .Values.disableHostPort }}
    name: local
{{- else }}
    name:  {{ .Values.global.provider.name }}
{{- end }}
{{- end }}


{{/* configure to docker repository */}}
{{- define "confluent-operator.docker-repo" }}
    docker_repo: {{ .Values.global.provider.registry.fqdn }}
{{- end }}

{{/* configure to docker repository */}}
{{- define "confluent-operator.cluster-id" }}
{{- print .Release.Namespace }}
{{- end }}

{{/* configure to psc version */}}
{{- define "confluent-operator.psc-version" }}
version:
  plugin: v1.0.0
  psc: "1.0.0"
{{- end }}


{{/*
This function expects kafka dict which can be passed as a global function
The function return protocol name as supported by Kafka
1. SASL_PLAINTEXT
2. SASL_SSL
3. PLAINTEXT
4. SSL
5. 2WAYSSL (*Custom)
*/}}
{{- define "confluent-operator.kafka-external-advertise-protocol" }}
{{ $kafka := $.kafkaDependency }}
{{- if not $kafka.tls.enabled }}
    {{- print "SASL_PLAINTEXT" -}}
{{- else if not $kafka.tls.authentication }}
    {{- if $kafka.tls.internal }}
        {{- print "SSL" -}}
    {{- else}}  
        {{- "PLAINTEXT" -}} 
    {{- end }}
{{- else if $kafka.tls.authentication.type }}
    {{- if (eq $kafka.tls.authentication.type "plain") }}
        {{- if $kafka.tls.internal }}
            {{- "SASL_SSL" -}}
        {{- else }}
            {{- print "SASL_PLAINTEXT" -}}
        {{- end }}
    {{- else if eq $kafka.tls.authentication.type "tls" }}
        {{- if $kafka.tls.internal }}
            {{- print "2WAYSSL" -}}
        {{- else }}
            {{- "PLAINTEXT" -}}
        {{- end }}
    {{- else }}
        {{- $_ := fail "Supported authentication type is plain/tls" }}
    {{- end }}
{{- else if empty $kafka.tls.authentication.type }}
    {{- if $kafka.tls.internal }}
        {{- print "SSL" -}}
    {{- else}}  
        {{- "PLAINTEXT" -}} 
    {{- end }}
{{- end }}
{{- end }}

{{/*
Configure Kafka client security configurations
*/}}
{{- define "confluent-operator.kafka-client-security" }}
{{- $protocol :=  (include "confluent-operator.kafka-external-advertise-protocol" .) | trim  }}
{{- if contains "SASL" $protocol }}
{{ printf "security.protocol=%s" $protocol }} 
{{ printf "sasl.mechanism=PLAIN" }}
{{ printf "sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${file:/mnt/secrets/global_sasl_plain_username:username}\" password=\"${file:/mnt/secrets/global_sasl_plain_password:password}\";" }}
{{- else }}
{{- if contains "2WAYSSL" $protocol }}
{{ printf "security.protocol=%s" "SSL" }}
{{ printf "ssl.keystore.location=/tmp/keystore.jks" }}
{{ printf "ssl.keystore.password=${file:/mnt/secrets/jksPassword.txt:jksPassword}" }}
{{ printf "ssl.key.password=${file:/mnt/secrets/jksPassword.txt:jksPassword}" }}
{{- else }}
{{ printf "security.protocol=%s" $protocol }} 
{{- end }}
{{- end }}
{{- if .Values.tls.cacerts }}
{{- if or (or (eq $protocol "SSL") (eq $protocol "SASL_SSL") ) (eq $protocol "2WAYSSL") }}
{{ printf "ssl.truststore.location=/tmp/truststore.jks"}}
{{ printf "ssl.truststore.password=${file:/mnt/secrets/jksPassword.txt:jksPassword}" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Configure Kafka client security configurations
*/}}
{{- define "confluent-operator.global-sasl-secret" }}
global_sasl_plain_username: {{ (printf "username=%s" .Values.global.sasl.plain.username) | b64enc }}
global_sasl_plain_password: {{ (printf "password=%s" .Values.global.sasl.plain.password) | b64enc }}
{{- end }}

{{/*
Configure Producer Configurations
*/}}
{{- define "confluent-operator.producer-security-config" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.rbac-sasl-oauth-config" .)  }}
{{- if not (empty $val) }}
{{ printf "producer.%s" $val }}
{{- end }}
{{- end }}
{{- else }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "producer.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}
{{- end }}


{{/*
Configure Consumer Configurations
*/}}
{{- define "confluent-operator.consumer-security-config" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.rbac-sasl-oauth-config" .)  }}
{{- if not (empty $val) }}
{{ printf "consumer.%s" $val }}
{{- end }}
{{- end }}
{{- else }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .) }}
{{- if not (empty $val) }}
{{ printf "consumer.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Producer Monitoring Interceptor Configurations
*/}}
{{- define "confluent-operator.producer-interceptor-security-config" }}
{{ print "producer.interceptor.classes=io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.rbac-sasl-oauth-config" .)  }}
{{- if not (empty $val) }}
{{ printf "producer.confluent.monitoring.interceptor.%s" $val }}
{{- end }}
{{- end }}
{{- else }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "producer.confluent.monitoring.interceptor.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Consumer Monitoring Interceptor Configurations
*/}}
{{- define "confluent-operator.consumer-interceptor-security-config" }}
{{ print "consumer.interceptor.classes=io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.rbac-sasl-oauth-config" .)  }}
{{- if not (empty $val) }}
{{ printf "consumer.confluent.monitoring.interceptor.%s" $val }}
{{- end }}
{{- end }}
{{- else }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "consumer.confluent.monitoring.interceptor.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Metric Reporter security configuration
*/}}
{{- define "confluent-operator.metric-reporter-security-config" }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "confluent.metrics.reporter.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "confluent-operator.cr-pod-security-config" }}
{{- if not .Values.global.pod.randomUID }}
podSecurityContext:
{{- if .Values.global.pod.securityContext.fsGroup }}
  fsGroup: {{ .Values.global.pod.securityContext.fsGroup }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsUser }}
  runAsUser: {{ .Values.global.pod.securityContext.runAsUser }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsGroup }}
  runAsGroup: {{ .Values.global.pod.securityContext.runAsGroup }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsNonRoot }}
  runAsNonRoot: {{ .Values.global.pod.securityContext.runAsNonRoot }}
{{- end }}
{{- if (ne (len .Values.global.pod.securityContext.supplementalGroups) 0) }}
  supplementalGroups:
{{ toYaml .Values.global.pod.securityContext.supplementalGroups | trim | indent 2 }}
{{- end }}
{{- if (ne (len .Values.global.pod.securityContext.seLinuxOptions) 0) }}
  seLinuxOptions:
{{ toYaml $.Values.global.pod.securityContext.seLinuxOptions | trim | indent 4 }}
{{- end }}
{{- else }}
podSecurityContext:
  randomUID: {{ .Values.global.pod.randomUID }}
{{- end }}
{{- end}}

{{/*
*/}}
{{- define "confluent-operator.psc-pod-security-config" }}
{{- if not .Values.global.pod.randomUID }}
pod_security_context:
{{- if .Values.global.pod.securityContext.fsGroup }}
  fs_group: {{ .Values.global.pod.securityContext.fsGroup }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsUser }}
  run_as_user: {{ .Values.global.pod.securityContext.runAsUser }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsGroup }}
  run_as_group: {{ .Values.global.pod.securityContext.runAsGroup }}
{{- end }}
{{- if .Values.global.pod.securityContext.runAsNonRoot }}
  run_as_non_root: {{ .Values.global.pod.securityContext.runAsNonRoot }}
{{- end }}
{{- if (ne (len .Values.global.pod.securityContext.supplementalGroups) 0) }}
  supplemental_groups:
{{ toYaml .Values.global.pod.securityContext.supplementalGroups | trim | indent 2 }}
{{- end }}
{{- if (ne (len .Values.global.pod.securityContext.seLinuxOptions) 0) }}
  selinux_options:
{{ toYaml $.Values.global.pod.securityContext.seLinuxOptions | trim | indent 4 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "confluent-operator.cr-config-overrides" }}
{{- if or .Values.configOverrides.server .Values.configOverrides.jvm .Values.configOverrides.log4j }}
configOverrides:
{{- if .Values.configOverrides.server }}
  server:
{{ toYaml .Values.configOverrides.server | trim | indent 2 }}
{{- end }}
{{- if .Values.configOverrides.jvm }}
  jvm:
{{ toYaml .Values.configOverrides.jvm | trim | indent 2 }}
{{- end }}
{{- if .Values.configOverrides.log4j }}
  log4j:
{{ toYaml .Values.configOverrides.log4j | trim | indent 2 }}
{{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "confluent-operator.telemetry" }}
{{- $telemetry := .Values.telemetry | default .Values.global.telemetry }}
{{- if and .telemetrySupported $telemetry.enabled }}
metric.reporters=io.confluent.telemetry.reporter.TelemetryReporter
confluent.telemetry.enabled=true
confluent.telemetry.api.key=${file:/mnt/secrets/{{ $telemetry.secretRef }}/telemetry:apiKey}
confluent.telemetry.api.secret=${file:/mnt/secrets/{{ $telemetry.secretRef }}/telemetry:apiSecret}
confluent.telemetry.labels.confluent.operator.version=0.419.0
{{- if $telemetry.proxy }}
confluent.telemetry.proxy.url=${file:/mnt/secrets/{{ $telemetry.secretRef }}/telemetry:proxyUrl}
confluent.telemetry.proxy.username=${file:/mnt/secrets/{{ $telemetry.secretRef }}/telemetry:proxyUsername}
confluent.telemetry.proxy.password=${file:/mnt/secrets/{{ $telemetry.secretRef }}/telemetry:proxyPassword}
{{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "confluent-operator.route" }}
{{- $targetPort := $.targetPort }}
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  {{- if $.Values.loadBalancer.annotations }}
  annotations:
{{ toYaml .Values.loadBalancer.annotations | trim | indent 4 }}
  {{- end }}
  name: {{ .Values.name }}-bootstrap
  namespace: {{ .Release.Namespace }}
spec:
  {{- if empty $.Values.loadBalancer.prefix }}
  host: {{ .Values.name }}.{{ .Values.loadBalancer.domain }}
  {{- else }}
  host: {{ $.Values.loadBalancer.prefix }}.{{- $.Values.loadBalancer.domain }}
  {{- end }}
  {{- if .Values.tls.enabled }}
  {{- if .Values.loadBalancer.wildCardPolicy }}
  wildcardPolicy: Subdomain
  {{- end }}
  tls:
    termination: passthrough
  {{- end }}
  port:
    targetPort: external
  to:
    kind: Service
    name: {{ .Values.name }}
{{- end }}

{{/*
JVM security configurations
*/}}
{{- define "confluent-operator.jvm-security-configs"}}
{{- $authenticationType := $.authType }}
{{- $tls := $.tlsEnable }}
{{- if $tls }}
{{- $_ := required "Fullchain PEM cannot be empty" .Values.tls.fullchain }}
{{- $_ := required "Private key pem cannot be empty." .Values.tls.privkey }}
{{- if (eq  $authenticationType "tls") }}
-Djavax.net.ssl.keyStore=/tmp/keystore.jks
-Djavax.net.ssl.keyStorePassword=<<keystorepassword>>
-Djavax.net.ssl.keyStoreType=pkcs12
{{- end }}
{{- if .Values.tls.cacerts }}
-Djavax.net.ssl.trustStore=/tmp/truststore.jks
-Djavax.net.ssl.trustStorePassword=<<keystorepassword>>
{{- end }}
{{- end }}
{{- end }}

{{/*
Init container configurations
*/}}
{{- define "confluent-operator.psc-init-container" }}
{{- $_ := required "requires init-container image repository" .Values.global.initContainer.image.repository }}
{{- $_ := required "requires init-container image tag" .Values.global.initContainer.image.tag }}
init_containers:
- name: init-container
  image: {{ .Values.global.initContainer.image.repository -}}:{{- .Values.global.initContainer.image.tag }}
  {{- include "confluent-operator.init-container-parameter" . | indent 2 }}
{{- end }}

{{- define "confluent-operator.init-container-parameter" }}
command:
- /bin/sh
- -xc
args:
- until [ -f /mnt/config/pod/{{ .Values.name }}/template.jsonnet ]; do echo "file not found"; sleep 10s; done; /opt/startup.sh
{{- end }}

{{/*
Init container configurations
*/}}
{{- define "confluent-operator.cr-init-container" }}
{{- $_ := required "requires init-container image repository" .Values.global.initContainer.image.repository }}
{{- $_ := required "requires init-container image tag" .Values.global.initContainer.image.tag }}
initContainers:
- name: init-container
  image: {{ .Values.global.provider.registry.fqdn }}/{{ .Values.global.initContainer.image.repository -}}:{{- .Values.global.initContainer.image.tag }}
  {{- include "confluent-operator.init-container-parameter" . | indent 2 }}
{{- end }}

{{/*
jsonnet template
*/}}
{{- define "confluent-operator.template-psc" }}
{{- $domainName := $.domainName }}
// pod's cardinal value
local podID = std.extVar("id");
// log4j setting
local log4jSetting(name, namespace, id) = {
   local log4JSetting = "app:%s,clusterId:%s,server:%s" % [name, namespace, id],
   'log4j.appender.stdout.layout.fields': log4JSetting,
   'log4j.appender.jsonlog.layout.fields': log4JSetting
};
// component endpoint setting
local componentEndpoint(compName, namespace, name, clusterDomain) =  std.join(".", ["%s" % name,"%s" % compName,"%s" % namespace,"%s" % clusterDomain]);
// jvm setting
local jvmSettings(compName, namespace, name, clusterDomain) = {
    '-Djava.rmi.server.hostname': componentEndpoint(compName, namespace, name, clusterDomain),
};
// get's value from either scheduler-plugins or helm charts
local podNamespace = {{ .Release.Namespace | quote }};
local componentName = {{ .Values.name | quote }};
local podName = std.join("-", ["%s" % componentName, "%s" % podID]);
local k8sClusterDomain = {{ $domainName | quote }};
{
  'jvm.config': jvmSettings(componentName, podNamespace, podName, k8sClusterDomain),
  'log4j.properties': log4jSetting(componentName, podNamespace, podID),
{{- if or (eq .Chart.Name "connect")  (eq .Chart.Name "replicator") }}
  '{{ .Chart.Name }}.properties': {
      'rest.advertised.host.name': componentEndpoint(componentName, podNamespace, podName, k8sClusterDomain),
      'rest.advertised.host.port': "8083",
      {{- if and .Values.tls.enabled .Values.tls.internalTLS }}
      'rest.advertised.listener': "https",
      {{- else }}
      'rest.advertised.listener': "http",
      {{- end }}
    },
{{- end }}
{{- if eq .Chart.Name "schemaregistry"  }}
  'schema-registry.properties': {
      "host.name": componentEndpoint(componentName, podNamespace, podName, k8sClusterDomain),
    },
{{- end }}
{{- if eq .Chart.Name "ksql"  }}
  'ksqldb-server.properties': {
      'host.name': componentEndpoint(componentName, podNamespace, podName, k8sClusterDomain),
    },
{{- end }}
{{- if eq .Chart.Name "controlcenter"  }}
  'control-center.properties': {
      'confluent.controlcenter.id' : podID,
    },
{{- end }}
}
{{- end }}

{{/*
This will generate sha256sum by omitting fields which does not require annotations update
to trigger rolls. This is short-term changes till we move psc structure gradually to component-manager.
*/}}
{{- define "confluent-operator.generate-sha256sum" }}
{{ $update := omit $.Values "replicas" "placement" "image" "nodeAffinity" "rack" "resources" "disableHostPort" }}
{{- $value :=  toYaml $update | sha256sum | quote }}
{{- print $value }}
{{- end }}

{{/*
Component REST endpoint
*/}}
{{- define "confluent-operator.dns-name" }}
{{- if empty $.Values.loadBalancer.prefix }}
dns: {{ $.Values.name }}.{{- $.Values.loadBalancer.domain }}
{{- else }}
dns: {{ $.Values.loadBalancer.prefix }}.{{- $.Values.loadBalancer.domain }}
{{- end }}
{{- end }}

{{/*
Confluent Component Resource Requirements
*/}}
{{- define "confluent-operator.resource-requirements" }}
requests:
{{- if .Values.resources.requests }}
{{ toYaml .Values.resources.requests | trim | indent 2 }}
{{- else }}
{{ toYaml .Values.resources | trim | indent 2 }}
{{- end }}
{{- if .Values.resources.limits }}
limits:
{{ toYaml .Values.resources.limits | trim | indent 2 }}
{{- end }}
{{- end }}

{{/*
Confluent Component Jolokia Security Settings
*/}}
{{- define "confluent-operator.jolokia-security-configs" }}
{{- $authenticationType := $.authType }}
{{- $tls := $.tlsEnable }}
{{- if $tls }}
{{- $_ := required "Fullchain PEM cannot be empty" .Values.tls.fullchain }}
{{- $_ := required "Private key pem cannot be empty." .Values.tls.privkey }}
- name: jolokia.config
  {{- if eq $authenticationType "tls" }}
  {{- $_ := required "Cacert pem cannot be empty for jmx mtls." .Values.tls.cacerts}}
  value: protocol=https,useSslClientAuthentication=true,keystore=/tmp/jolokia-keystore.jks,keystorePassword=<<keystorepassword>>
  {{- else }}
  value: protocol=https,useSslClientAuthentication=false,keystore=/tmp/jolokia-keystore.jks,keystorePassword=<<keystorepassword>>
  {{- end }}
{{- end }}
{{- end }}

{{/*
JMX security configurations
*/}}
{{- define "confluent-operator.jmx-security-configs"}}
{{- $jmxAuth := $.jmxAuthType }}
{{- $jmxTLS := $.jmxTLSEnable }}
{{- $depTLS := $.tlsEnable }}
{{- $depAuth := $.authType }}

{{- $tls := and $depTLS (not (eq  $depAuth "tls")) }}
{{- $setKeystore := and $jmxTLS (or (not $depTLS) $tls ) }}
{{- $setTruststore := and $jmxTLS (not $depTLS) }}

{{- if $setKeystore }}
{{- $_ := required "Fullchain PEM cannot be empty" .Values.tls.fullchain }}
{{- $_ := required "Private key pem cannot be empty." .Values.tls.privkey }}
-Djavax.net.ssl.keyStore=/tmp/keystore.jks
-Djavax.net.ssl.keyStorePassword=<<keystorepassword>>
-Djavax.net.ssl.keyStoreType=pkcs12
{{- end }}

{{- if and $setTruststore .Values.tls.cacerts }}
-Djavax.net.ssl.trustStore=/tmp/truststore.jks
-Djavax.net.ssl.trustStorePassword=<<keystorepassword>>
{{- end }}

{{- if $jmxTLS }}
-Dcom.sun.management.jmxremote.ssl=true
-Dcom.sun.management.jmxremote.registry.ssl=true
{{- if eq $jmxAuth "tls" }}
{{- $_ := required "Cacert pem cannot be empty for jmx mtls." .Values.tls.cacerts}}
-Dcom.sun.management.jmxremote.ssl.need.client.auth=true
{{- else }}
-Dcom.sun.management.jmxremote.ssl.need.client.auth=false
{{- end }}
{{- else }}
-Dcom.sun.management.jmxremote.ssl=false
{{- end }}
{{- end }}

{{/*
Properties config file provider
*/}}
{{- define "confluent-operator.config-file-provider"}}
{{ printf "config.providers=file" }}
{{ printf "config.providers.file.class=org.apache.kafka.common.config.provider.FileConfigProvider" }}
{{- end }}
{{/*
Confluent cert validation
*/}}
{{- define "confluent-operator.cert-required" }}
{{- if or (or .Values.tls.enabled .Values.tls.jmxTLS) }}
{{- $_ := required "Fullchain PEM cannot be empty" .Values.tls.fullchain }}
{{- $_ := required "Private key pem cannot be empty." .Values.tls.privkey }}
{{- $_ := required "jksPassword cannot be empty" .Values.tls.jksPassword }}
{{- end }}
{{- end }}

{{/*
Confluent mds credential
*/}}
{{- define "confluent-operator.mds-credential-secret" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- $_ := required "MDS username required" .Values.dependencies.mds.authentication.username }}
{{- $_ := required "MDS password required" .Values.dependencies.mds.authentication.password }}
{{- $mdsUserName := $.Values.dependencies.mds.authentication.username }}
{{- $mdsPassword := $.Values.dependencies.mds.authentication.password }}
mds.txt: {{ (printf "credential=%s:%s\nusername=%s\npassword=%s" $mdsUserName $mdsPassword $mdsUserName $mdsPassword) | b64enc }}
{{- end }}
{{- end }}

{{/*
 MDS basic configuration
*/}}
{{- define "confluent-operator.cp-mds-config" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- $_ := required "MDS endpoint required e.g http|s://<kafka_endpoint>" .Values.global.dependencies.mds.endpoint }}
{{- $_ := required "MDS token public key required" .Values.global.dependencies.mds.publicKey }}
confluent.metadata.bootstrap.server.urls={{ .Values.global.dependencies.mds.endpoint }}
confluent.metadata.basic.auth.user.info=${file:/mnt/secrets/mds.txt:credential}
public.key.path=/mnt/sslcerts/mdsPublicKey.pem
{{- end }}
{{- end }}

{{/*
 MDS public key configuration
*/}}
{{- define "confluent-operator.mds-publickey" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- $_ := required "MDS public key cannot be empty" .Values.global.dependencies.mds.publicKey }}
mdsPublicKey.pem: {{ .Values.global.dependencies.mds.publicKey | b64enc }}
{{- end }}
{{- end }}

{{/*
 RBAC SASL OUATH Configurations
*/}}
{{- define "confluent-operator.rbac-sasl-oauth-config" }}
{{- $_ := required "MDS endpoint required e.g http|s://<kafka_endpoint>" .Values.global.dependencies.mds.endpoint }}
{{- $_ := required "MDS username required" .Values.dependencies.mds.authentication.username }}
{{- $_ := required "MDS password required" .Values.dependencies.mds.authentication.password }}
{{- $mdsEndpoint := $.Values.global.dependencies.mds.endpoint }}
{{ $kafka := $.kafkaDependency }}
{{- $class := "org.apache.kafka.common.security.oauthbearer.OAuthBearerLoginModule" }}
{{ printf "sasl.jaas.config=%s required metadataServerUrls=\"%s\" username=\"${file:/mnt/secrets/mds.txt:username}\" password=\"${file:/mnt/secrets/mds.txt:password}\";" $class $mdsEndpoint}}
sasl.login.callback.handler.class=io.confluent.kafka.clients.plugins.auth.token.TokenUserLoginCallbackHandler
sasl.mechanism=OAUTHBEARER
{{- if $kafka.tls.enabled  }}
security.protocol=SASL_SSL
{{- if .Values.tls.cacerts }}
ssl.truststore.location=/tmp/truststore.jks
ssl.truststore.password=${file:/mnt/secrets/jksPassword.txt:jksPassword}
{{- end }}
{{- else }}
security.protocol=SASL_PLAINTEXT
{{- end }}
{{- end }}


{{/*
Confluent PSC Node Affinity Rules
---------------------------------
PSC Node Affinity Rule uses integer rules instead of string hence we must convert the user input
*/}}
{{- define "confluent-operator.psc-node-affinity" }}
{{- if eq (.rule | default "PREFERRED") "REQUIRED" }}
rule: 1
{{- else }}
rule: 0
{{- end }}
key: {{ toYaml .key | trim }}
values:
{{ toYaml .values | trim }}
{{- end }}

{{/*
Confluent PSC Pod [Anti]Affinity Rules
--------------------------------------
PSC Pod [Anti]Affinity Rule uses integer rules instead of string hence we must convert the user input
*/}}
{{- define "confluent-operator.psc-pod-affinity" }}
{{- if eq (.rule | default "PREFERRED") "REQUIRED" }}
rule: 1
{{- else }}
rule: 0
{{- end }}
terms:
{{ toYaml .terms | trim }}
{{- end }}

{{/*
Confluent Component Affinity Rules
*/}}
{{- define "confluent-operator.affinity" }}
{{- if or (or .Values.affinity.nodeAffinity .Values.affinity.podAffinity) .Values.affinity.podAntiAffinity }}
affinity:
{{- if .Values.affinity.nodeAffinity }}
{{- if .Values.nodeAffinity }}
{{- fail "Only one between .Values.affinity.nodeAffinity and .Values.nodeAffinity can be set." }}
{{- end }}
{{- if eq .isPSC "true" }}
  node_affinity:
{{- include "confluent-operator.psc-node-affinity" .Values.affinity.nodeAffinity | indent 4 }}
{{- else }}
  nodeAffinity:
{{ toYaml .Values.affinity.nodeAffinity | trim | indent 4 }}
{{- end }}
{{- end }}
{{- if .Values.affinity.podAffinity }}
{{- if eq .isPSC "true" }}
  pod_affinity:
{{- include "confluent-operator.psc-pod-affinity" .Values.affinity.podAffinity | indent 4 }}
{{- else }}
  podAffinity:
{{ toYaml .Values.affinity.podAffinity | trim | indent 4 }}
{{- end }}
{{- end }}
{{- if .Values.affinity.podAntiAffinity }}
{{- if .Values.rack }}
{{- fail "Only one between .Values.affinity.podAntiAffinity and .Values.rack can be set." }}
{{- end }}
{{- if eq .isPSC "true" }}
  pod_anti_affinity:
{{- include "confluent-operator.psc-pod-affinity" .Values.affinity.podAntiAffinity | indent 4 }}
{{- else }}
  podAntiAffinity:
{{ toYaml .Values.affinity.podAntiAffinity | trim | indent 4 }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Confluent Component Deprecated Features In-Use List
*/}}
{{- define "confluent-operator.deprecated-list" }}
{{- if .nodeAffinity }}
- [WARNING]: .Values.nodeAffinity is deprecated. We recommend using .Values.affinity.nodeAffinity instead.
{{- end }}
{{- if .rack }}
- [WARNING]: .Values.rack is deprecated. We recommend using .Values.affinity.podAntiAffinity instead.
{{- end }}
{{- if not .disableHostPort }}
- [WARNING]: .Values.disableHostPort is deprecated. We recommend using .Values.oneReplicaPerNode instead.
{{- end }}
{{- end }}

{{/*
CR Mounted Secrets List
*/}}
{{- define "confluent-operator.cr-mounted-secrets" }}
{{- $telemetry := .Values.telemetry | default .Values.global.telemetry }}
{{- if or .Values.mountedSecrets (and .telemetrySupported $telemetry.enabled) }}
mountedSecrets:
{{- if .Values.mountedSecrets }}
{{ toYaml .Values.mountedSecrets | trim }}
{{- end }}
{{- if and .telemetrySupported $telemetry.enabled }}
- secretRef: {{ $telemetry.secretRef }}
{{- end }}
{{- end }}
{{- end }}

{{/*
PSC Mounted Secrets List
*/}}
{{- define "confluent-operator.psc-mounted-secrets" }}
{{- $telemetry := .Values.telemetry | default .Values.global.telemetry }}
{{- if or .Values.mountedSecrets (and .telemetrySupported $telemetry.enabled) }}
mounted_secrets:
{{- range $i, $secret := .Values.mountedSecrets }}
- secret_ref: {{ $secret.secretRef }}
{{- if $secret.keyItems }}
  key_items:
{{ toYaml $secret.keyItems | trim | indent 2 }}
{{- end }}
{{- end }}
{{- if and .telemetrySupported $telemetry.enabled }}
- secret_ref: {{ $telemetry.secretRef }}
{{- end }}
{{- end }}
{{- end }}
