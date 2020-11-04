{{/*
Kafka client configuration; individual brokers are required for KSQL
*/}}
{{- define "ksql.kafka-configuration" }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- $endpoint :=  (index (split ":" .Values.dependencies.kafka.bootstrapEndpoint) "_0") }}
bootstrap.servers.admin={{ .Values.dependencies.kafka.bootstrapEndpoint }}
bootstrap.servers={{ printf "%s:9073" $endpoint }}
{{ include "confluent-operator.rbac-sasl-oauth-config" . | trim }}
{{- else }}
bootstrap.servers={{ .Values.dependencies.kafka.brokerEndpoints }}
{{- include "confluent-operator.kafka-client-security" . }}
{{- end }}
{{- end }}

{{/*
Monitoring Interceptor Configurations
*/}}
{{- define "ksql.interceptor-security-config" }}
{{ print "producer.interceptor.classes=io.confluent.monitoring.clients.interceptor.MonitoringProducerInterceptor" }}
{{ print "consumer.interceptor.classes=io.confluent.monitoring.clients.interceptor.MonitoringConsumerInterceptor" }}
{{- if empty .Values.dependencies.interceptor.bootstrapEndpoint }}
{{ printf "confluent.monitoring.interceptor.bootstrap.servers=%s" .Values.dependencies.kafka.bootstrapEndpoint }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{- else }} 
{{ printf "confluent.monitoring.interceptor.bootstrap.servers=%s" .Values.dependencies.interceptor.bootstrapEndpoint }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.interceptor }}
{{- end }}
{{- range $key, $val := splitList "\n" (include "confluent-operator.kafka-client-security" .)  }}
{{- if not (empty $val) }}
{{ printf "confluent.monitoring.interceptor.%s" $val }} 
{{- end }}
{{- end }}
{{- end }}
