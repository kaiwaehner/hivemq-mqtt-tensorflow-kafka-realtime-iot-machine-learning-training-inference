{{/*
Configure JVM configuration for SchemaRegistry.
*/}}
{{- define "schemaregistry.jvm-config" }}

-Xmx {{- $.Values.jvmConfig.heapSize }}
-Xms {{- $.Values.jvmConfig.heapSize }}
-server
-XX:MetaspaceSize=96m
-XX:+UseG1GC
-XX:MaxGCPauseMillis=20
-XX:InitiatingHeapOccupancyPercent=35
-XX:+ExplicitGCInvokesConcurrent
-XX:G1HeapRegionSize=16
-XX:MinMetaspaceFreeRatio=50
-XX:MaxMetaspaceFreeRatio=80
-Djava.awt.headless=true
-XX:ParallelGCThreads=1
-Djdk.tls.ephemeralDHKeySize=2048
-XX:ConcGCThreads=1
-Dcom.sun.management.jmxremote=true
-Dcom.sun.management.jmxremote.authenticate=false
-Dcom.sun.management.jmxremote.local.only=false
-Dcom.sun.management.jmxremote.rmi.port=7203
-Dcom.sun.management.jmxremote.port=7203
-XX:+PrintFlagsFinal
-XX:+UnlockDiagnosticVMOptions
{{- $_ := set $ "tlsEnable" false }}
{{- $_ := set $ "authType" "" }}
{{- $_ := set $ "jmxTLSEnable" .Values.tls.jmxTLS }}
{{- $_ := set $ "jmxAuthType" .Values.tls.jmxAuthentication.type }}
{{- include "confluent-operator.jvm-security-configs" . }}
{{- include "confluent-operator.jmx-security-configs" . }}
{{- end }}

{{- define "schemaregistry.rbac-kafka-config" }}
{{- $_ := set $ "kafkaDependency" .Values.dependencies.kafka }}
{{- $protocol :=  (include "confluent-operator.kafka-external-advertise-protocol" .) | trim  }}
{{- $endpoint :=  (index (split ":" .Values.dependencies.kafka.bootstrapEndpoint) "_0") }}
{{- $bootstrap := printf "%s:9073" $endpoint }}
{{- if contains "SASL" $protocol }}
{{  printf "kafkastore.bootstrap.servers.admin=%s://%s" $protocol .Values.dependencies.kafka.bootstrapEndpoint }}
{{- else }}
{{- if contains "2WAYSSL" $protocol }}
{{ printf "kafkastore.bootstrap.servers.admin=SSL://%s" .Values.dependencies.kafka.bootstrapEndpoint }}
{{- else }}
{{ printf "kafkastore.bootstrap.servers.admin=%s://%s" $protocol .Values.dependencies.kafka.bootstrapEndpoint }}
{{- end }}
{{- end }}
{{- if .Values.dependencies.kafka.tls.enabled }}
{{ printf "kafkastore.bootstrap.servers=SASL_SSL://%s" $bootstrap  }}
{{- else }}
{{ printf "kafkastore.bootstrap.servers=SASL_PLAINTEXT://%s" $bootstrap }}
{{- end }}
{{- range $i, $val := splitList "\n" ( include "confluent-operator.rbac-sasl-oauth-config" . | trim ) }}
{{- if not (empty $val) }}
{{ printf "kafkastore.%s" $val }}
{{- end }}
{{- end }}
{{- end }}

{{- define "schemaregistry.kafka-config" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- include "schemaregistry.rbac-kafka-config" . }}
{{- else }}
{{- $protocol :=  (include "confluent-operator.kafka-external-advertise-protocol" .) | trim  }}
{{- $bootstrap :=  .Values.dependencies.kafka.bootstrapEndpoint }}
{{- if contains "SASL" $protocol }}
{{ printf "kafkastore.bootstrap.servers=%s://%s" $protocol $bootstrap }}
{{- else }}
{{- if contains "2WAYSSL" $protocol }}
{{ printf "kafkastore.bootstrap.servers=SSL://%s" $bootstrap }}
{{- else }}
{{ printf "kafkastore.bootstrap.servers=%s://%s" $protocol $bootstrap }}
{{- end }}
{{- end }}
{{- range $i, $val := splitList "\n" ( include "confluent-operator.kafka-client-security" . | trim ) }}
{{- if not (empty $val) }}
{{ printf "kafkastore.%s" $val }}
{{- end }}
{{- end }}
{{- end }}
{{- end }}
