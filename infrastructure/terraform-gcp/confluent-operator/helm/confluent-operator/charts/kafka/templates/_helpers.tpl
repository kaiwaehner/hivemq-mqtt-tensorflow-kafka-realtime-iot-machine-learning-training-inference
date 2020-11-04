{{/*
Configure Confluent Metric Reporters
*/}}
{{- define "kafka.confluent-metric-reporter" }}
{{- $_ := set $ "kreplicas" .Values.replicas }}
metricReporter:
  enabled: {{ .Values.metricReporter.enabled }}
  {{- if  empty .Values.metricReporter.bootstrapEndpoint }}
  bootstrapEndpoint: {{ .Values.name }}:9071
  {{- else }}
  bootstrapEndpoint: {{ .Values.metricReporter.bootstrapEndpoint }}
  {{- end }}
  publishMs: {{ .Values.metricReporter.publishMs }}
  {{- if  empty .Values.metricReporter.replicationFactor }}
  replicationFactor: {{ include  "confluent-operator.replication_count" . }}
  {{- else }}
  replicationFactor: {{ .Values.metricReporter.replicationFactor }}
  {{- end }}
  internal: {{ .Values.metricReporter.tls.internal }}
  tls:
    enabled: {{ .Values.metricReporter.tls.enabled }}
    {{- if and .Values.metricReporter.tls.authentication (not (empty .Values.metricReporter.tls.authentication.type))}}
    authentication:
        type: {{ .Values.metricReporter.tls.authentication.type }}
    {{- end }}
{{- end }}

{{/*
Create SASL Users
*/}}
{{- define "kafka.sasl_users" }}
{{- $result := dict "users" (list) }}
{{- range $i, $value := .Values.sasl.plain }}
{{- $users := split "=" $value }}
{{- $user := index $users "_0" }}
{{- $pass := index $users "_1" }}
{{- if eq $user $.Values.global.sasl.plain.username }}
{{- fail "global.sasl.plain.username must not contain in sasl.plain" }}
{{- end }}
{{- if empty $pass }}
{{- fail "password is required..."}}
{{- end }}
{{- end }}
{{- $totalUsers := append .Values.sasl.plain (printf "%s=%s" .Values.global.sasl.plain.username .Values.global.sasl.plain.password) }}
{{- range $i, $value := $totalUsers }}
{{- $users := split "=" $value }}
{{- $user := index $users "_0" }}
{{- $pass := index $users "_1" }}
{{- $ignore := (printf " \"%s\": { \"sasl_mechanism\": \"PLAIN\", \"hashed_secret\": \"%s\", \"hash_function\": \"none\", \"logical_cluster_id\": \"%s\", \"user_id\": \"%s\"}" $user $pass $.Release.Namespace $user) | append $result.users | set $result "users" }}
{{- end }}
{{- printf "{ \"keys\": { %s}}" (join ", " $result.users) }}
{{- end }}

{{/*
Create RBAC/ACL configurations
*/}}
{{- define "kafka.rbac_ldap" }}
ldap:
  authentication:
    type: simple
{{- $_ := required "ldap address required" .Values.services.mds.ldap.address }}
  address: {{ .Values.services.mds.ldap.address }}
  configurations:
{{ toYaml .Values.services.mds.ldap.configurations | indent 4 }}
{{- end }}

{{/*
Define the rules to validate kafka external access.
*/}}
{{- define "kafka.external_access.validation" }}
{{- $count := 0 }}
{{- if .Values.loadBalancer.enabled }}
{{ $count = add $count 1 }}
{{- end }}
{{- if .Values.nodePort.enabled }}
{{ $count = add $count 1 }}
{{- end }}
{{- if .Values.staticForPortBasedRouting.enabled }}
{{ $count = add $count 1 }}
{{- end }}
{{- if .Values.staticForHostBasedRouting.enabled }}
{{ $count = add $count 1 }}
{{- end }}
{{- if gt $count 1 }}
{{- fail "only one of the following external access polices [loadBalancer, nodePort, staticForPortBasedRouting, staticForHostBasedRouting] can be enabled." }}
{{- end }}
{{- end }}

{{/*
Define the network for kafka external access.
*/}}
{{- define "kafka.cr-external_access.network" }}
{{/*
The reason to have duplicate if check here is to make sure the error only one service is allowed to be enabled fails before required fields's validation.
*/}}
{{- include "kafka.external_access.validation" . }}
{{- if .Values.loadBalancer.enabled }}
{{- $_ := required "Domain name (DNS) for Kafka external access (loadBalancer) is required" .Values.loadBalancer.domain }}
{{- $_ := required "Type for Kafka external access (loadBalancer) is required" .Values.loadBalancer.type }}
network:
  serviceType: "loadBalancer"
  domain: {{ .Values.loadBalancer.domain }}
  type: {{ .Values.loadBalancer.type }}
  {{- if .Values.loadBalancer.annotations }}
  annotations:
{{ toYaml .Values.loadBalancer.annotations | trim | indent 6 }}
  {{- end }}
  {{- if .Values.loadBalancer.bootstrapPrefix }}
  bootstrapPrefix: {{ .Values.loadBalancer.bootstrapPrefix }}
  {{- end }}
  {{- if .Values.loadBalancer.brokerPrefix }}
  brokerPrefix: {{ .Values.loadBalancer.brokerPrefix }}
  {{- end }}
{{- end }}
{{- if .Values.nodePort.enabled }}
{{- $_ := required "Host name for Kafka external access (nodePort) is required" .Values.nodePort.host }}
{{- $_ := required "PortOffset for Kafka external access (nodePort) is required" .Values.nodePort.portOffset }}
network:
  serviceType : "nodePort"
  host: {{ .Values.nodePort.host }}
  portOffset: {{ .Values.nodePort.portOffset }}
  {{- if .Values.nodePort.annotations }}
  annotations:
{{ toYaml .Values.nodePort.annotations | trim | indent 6 }}
  {{- end }}
{{- end }}
{{- if .Values.staticForPortBasedRouting.enabled }}
{{- $_ := required "Host name for Kafka external access (staticForPortBasedRouting) is required" .Values.staticForPortBasedRouting.host }}
{{- $_ := required "PortOffset for Kafka external access (staticForPortBasedRouting) is required" .Values.staticForPortBasedRouting.portOffset }}
network:
  serviceType: "staticForPortBasedRouting"
  host: {{ .Values.staticForPortBasedRouting.host }}
  portOffset: {{ .Values.staticForPortBasedRouting.portOffset }}
{{- end }}
{{- if .Values.staticForHostBasedRouting.enabled }}
{{- $_ := required "Domain name (DNS) for Kafka external access (staticForHostBasedRouting) is required" .Values.staticForHostBasedRouting.domain }}
{{- $_ := required "Port for Kafka external access (staticForHostBasedRouting) is required" .Values.staticForHostBasedRouting.port }}
network:
  serviceType: "staticForHostBasedRouting"
  domain: {{ .Values.staticForHostBasedRouting.domain }}
  port: {{ .Values.staticForHostBasedRouting.port }}
  {{- if .Values.staticForHostBasedRouting.bootstrapPrefix }}
  bootstrapPrefix: {{ .Values.staticForHostBasedRouting.bootstrapPrefix }}
  {{- end }}
  {{- if .Values.staticForHostBasedRouting.brokerPrefix }}
  brokerPrefix: {{ .Values.staticForHostBasedRouting.brokerPrefix }}
  {{- end }}
{{- end }}
{{- end }}

{{/*
*/}}
{{- define "kafka.rest-proxy" }}
{{- if .Values.global.authorization.rbac.enabled }}
kafka.rest.enable=true
{{- if and (and .Values.tls.enabled .Values.loadBalancer.enabled) (not .Values.tls.internalTLS) }}
kafka.rest.bootstrap.servers={{ printf "%s.%s:9073" ( .Values.loadBalancer.bootstrapPrefix | default .Values.name ) .Values.loadBalancer.domain }}
{{- else }}
kafka.rest.bootstrap.servers={{ printf "%s.%s.%s:9073" .Values.name .Release.Namespace (.Values.global.provider.kubernetes.clusterDomain | default "svc.cluster.local") }}
{{- end }}
{{- if .Values.tls.enabled }}
kafka.rest.client.security.protocol=SASL_SSL
{{- if .Values.tls.cacerts }}
kafka.rest.client.ssl.truststore.location=/tmp/truststore.jks
kafka.rest.client.ssl.truststore.password=${file:/mnt/secrets/jksPassword.txt:jksPassword}
{{- end }}
{{- else }}
kafka.rest.client.security.protocol=SASL_PLAINTEXT
{{- end }}
{{- $_ :=  required "MDS endpoint required e.g http|s://<kafka_endpoint>" .Values.global.dependencies.mds.endpoint }}
{{- $_ :=  required "MDS token public key required" .Values.global.dependencies.mds.publicKey }}
kafka.rest.confluent.metadata.bootstrap.server.urls={{ .Values.global.dependencies.mds.endpoint }}
{{- if and .Values.tls.cacerts (contains "https" .Values.global.dependencies.mds.endpoint) }}
kafka.rest.confluent.metadata.ssl.truststore.location=/tmp/truststore.jks
kafka.rest.confluent.metadata.ssl.truststore.password=${file:/mnt/secrets/jksPassword.txt:jksPassword}
{{- end }}
kafka.rest.confluent.metadata.basic.auth.user.info=${file:/mnt/secrets/mds.txt:credential}
kafka.rest.public.key.path=/mnt/sslcerts/mdsPublicKey.pem
kafka.rest.confluent.metadata.http.auth.credentials.provider=BASIC
kafka.rest.kafka.rest.resource.extension.class=io.confluent.kafkarest.security.KafkaRestSecurityResourceExtension
kafka.rest.rest.servlet.initializor.classes=io.confluent.common.security.jetty.initializer.InstallBearerOrBasicSecurityHandler
{{- end }}
{{- end }}

{{/*
Kafka configuration override capabilities
*/}}
{{- define "kafka.config-overrides"}}
{{- $telemetry := .Values.telemetry | default .Values.global.telemetry }}
{{- if or .Values.configOverrides.server .Values.configOverrides.jvm .Values.configOverrides.log4j $telemetry.enabled .Values.global.authorization.rbac.enabled }}
configOverrides:
{{- if or .Values.configOverrides.server $telemetry.enabled .Values.global.authorization.rbac.enabled }}
  server:
{{- if .Values.configOverrides.server }}
{{ toYaml .Values.configOverrides.server | trim | indent 2 }}
{{- end }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- range $i, $value := splitList "\n" (include "kafka.rest-proxy" .) }}
{{- if $value }}
{{ printf "- %s" $value | indent 2 }}
{{- end }}
{{- end }}
{{- end }}
{{- if $telemetry.enabled }}
{{- range $i, $value := splitList "\n" (include "confluent-operator.telemetry" .) }}
{{- if $value }}
{{ printf "- %s" $value | indent 2 }}
{{- end }}
{{- end }}
{{- end }}
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
Rest Proxy MDS Credential
*/}}
{{- define "kafka.mds-credential-secret" }}
{{- if .Values.global.authorization.rbac.enabled }}
{{- $mdsUserName := $.Values.services.restProxy.authentication.username }}
{{- $mdsPassword := $.Values.services.restProxy.authentication.password }}
{{- $_ := required "MDS username required for restProxy Client" $mdsUserName }}
{{- $_ := required "MDS password required for restProxy Client" $mdsPassword }}
mds.txt: {{ (printf "credential=%s:%s\nusername=%s\npassword=%s" $mdsUserName $mdsPassword $mdsUserName $mdsPassword) | b64enc }}
{{- end }}
{{- end }}
