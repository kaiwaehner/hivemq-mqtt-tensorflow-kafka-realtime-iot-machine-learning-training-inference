{{/*
Kafka Steam security configuration for C3
*/}}
{{- define "c3.stream-security" }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.c3KafkaCluster }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "confluent.controlcenter.streams.%s" $val }} 
{{- end }}
{{- end }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}


{{/*
Kafka Stream security configuration for C3
*/}}
{{- define "c3.stream-security-config" }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.c3KafkaCluster}}
{{- if .Values.global.authorization.rbac.enabled }}
{{- $endpoint :=  (index (split ":" .Values.dependencies.c3KafkaCluster.bootstrapEndpoint) "_0") }}
{{- $tls := .Values.dependencies.c3KafkaCluster.tls.enabled }}
# added to support backward-compatibility with CP 5.5 Image
bootstrap.servers.admin={{ .Values.dependencies.c3KafkaCluster.bootstrapEndpoint }}
bootstrap.servers={{ printf "%s:9073" $endpoint }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.rbac-sasl-oauth-config" .) }}
{{- if not (empty $val) }}
{{ printf "confluent.controlcenter.streams.%s" $val }}
{{- end }}
{{- end }}
{{- if and (not (empty .Values.tls.cacerts)) $tls }}
confluent.controlcenter.streams.ssl.truststore.location=/tmp/truststore.jks
confluent.controlcenter.streams.ssl.truststore.password=${file:/mnt/secrets/jksPassword.txt:jksPassword}
{{- end }}
{{- else }}
bootstrap.servers={{ .Values.dependencies.c3KafkaCluster.bootstrapEndpoint }}
{{- include "c3.stream-security" . }}
{{- end }}
{{- end }}

{{/*
Configure Consumer Configurations
*/}}
{{- define "confluent-operator.consumer-security-config" }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .) }}
{{- if not (empty $val) }}
{{ printf "consumer.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "c3.embedded-rest-proxy-config" }}
{{ $rp := $.restProxy }}
{{- if $rp.enabled }}
{{- $_ := required "RestProxy URL is required e.g http://<kafa.name>.<namespace>.svc.cluster.local:8090" $rp.url}}
cprest.url={{$rp.url}}
{{- end }}
{{- end }}

{{/*
Monitoring Kafka Cluster configurations
*/}}
{{- define "c3.monitoring-clusters" }}
{{- if $.Values.dependencies.monitoringKafkaClusters }}
{{- range $index, $value := .Values.dependencies.monitoringKafkaClusters }}
{{- $_ := set $ "kafkaDependency" $value }}
{{- $cluster_name := index (pluck "name" $value) 0 }}
{{- $bootstrapEndpoint := index (pluck "bootstrapEndpoint" $value) 0 }}
{{- if empty $bootstrapEndpoint }}
{{- fail (printf "provide bootstrap-endpoint for cluster [%s]" $cluster_name) }}
{{- end }}
{{ printf "\n# Start monitoring cluster [%s] configurations\n" $cluster_name }}
{{- printf "confluent.controlcenter.kafka.%s.bootstrap.servers=%s" $cluster_name $bootstrapEndpoint }}
{{- $rp := set $ "restProxy" $value }}
{{- range $key, $val := splitList "\n" (include "c3.embedded-rest-proxy-config" $rp.restProxy)  }}
{{- if not (empty $val) }}
{{ printf "confluent.controlcenter.kafka.%s.%s" $cluster_name $val }}
{{- end }}
{{- end }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" $)  }}
{{- if not (empty $val) }}
{{- if contains "sasl.jaas.config" $val }}
{{- if and (hasKey $value "username") (hasKey $value "password") }}
{{ printf "confluent.controlcenter.kafka.%s.sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username=\"${file:/mnt/secrets/%s_global_sasl_plain_username:username}\" password=\"${file:/mnt/secrets/%s_global_sasl_plain_password:password}\";" $cluster_name $cluster_name $cluster_name }}
{{- else }}
{{ printf "confluent.controlcenter.kafka.%s.%s" $cluster_name $val }}
{{- end }}
{{- else }}
{{ printf "confluent.controlcenter.kafka.%s.%s" $cluster_name $val }}
{{- end }}
{{- end }}
{{- end }}
{{- printf "\n# End monitoring cluster [%s] configurations\n" $cluster_name }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Monitoring Kafka Cluster jaas secrets
*/}}
{{- define "c3.monitoring-clusters-sasl-secret" }}
{{- if $.Values.dependencies.monitoringKafkaClusters }}
{{- range $index, $value := .Values.dependencies.monitoringKafkaClusters }}
{{- $_ := set $ "kafkaDependency" $value }}
{{- $protocol :=  (include "confluent-operator.kafka-external-advertise-protocol" $) | trim  }}
{{- if contains "SASL" $protocol }}
{{- if and (hasKey $value "username") (hasKey $value "password") }}
{{- $cluster_name := index (pluck "name" $value) 0 }}
{{- $username := (printf "username=\"%s\"" $value.username) | b64enc }}
{{- $password := (printf "password=\"%s\"" $value.password) | b64enc }}
{{ printf "%s_global_sasl_plain_username: %s" $cluster_name $password }}
{{ printf "%s_global_sasl_plain_password: %s" $cluster_name $password }}
{{- $_ := unset $ "kafkaDependency" }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
