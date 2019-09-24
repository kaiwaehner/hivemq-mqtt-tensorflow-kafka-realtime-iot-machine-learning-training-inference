#!/usr/bin/env bash
set -e

### Usage and long print commands

DESC_show="Show the scenario of an active Scenario run"
DESC_log="Watch the commander log of an active Scenario run"
DESC_abort="Abort an active Scenario run"

function usage() {
  cat <<EOF
HiveMQ Device Simulator Kubernetes CLI

Commands:
    run         Execute a HiveMQ Device Simulator Scenario
    log         ${DESC_log}
    show        ${DESC_show}
    abort       ${DESC_abort}
    example     Show an example HiveMQ Device Simulator Scenario
    jobs        Show list of currently running HiveMQ Device Simulator Scenarios

Run ${KUBECTL_CMD} devsim <command> --help for more information
EOF
}

function usage_run() {
  cat <<EOF
Execute a HiveMQ Device Simulator Scenario

Usage:
    ${KUBECTL_CMD} devsim run -s scenario.xml [options]

Options:
    -s, --scenario:         Local path to HiveMQ Device Simulator scenario file to run. See the "example" command for a sample scenario. Required.
    -l, --label:            Label for the test. This must be unique when running multiple tests and will be used for annotations and labels. Will be randomly created based on timestamp if none specified.
    -a, --agent-count:      Override the number of HiveMQ Device Simulator Agents to create. Will default to 3.
    -n, --namespace:        The namespace to run the test in. Will use "default" if none is specified.
    --mem:                  The amount of memory to request in the Pod spec. (Default: 1G)
    --cpu:                  The amount of CPU to request in the Ppd spec. (Default: 500m)
    -d, --detach:           Do not show the log and run the test in the background.
    -L, --log-level:        Log level to run the commander with
    -A, --all-logs:         When displaying pod logs, show logs for all pods instead of only the commander's. Disabled by default. Can also be used on the log subcommand.
    --enable-monitoring:    Enable Prometheus Monitoring. Disabled by default.
    --rbac:                 Create RBAC rules for the initial commander pod. Disabled by default.
    --help:                 Print this help text.
EOF
}

function usage_misc() {
  CMD=$1
  desc_name="DESC_${CMD}"
  DESC=${!desc_name}

  cat <<EOF
$DESC

Usage:
    ${KUBECTL_CMD} devsim ${CMD} --label <test-label>
EOF
}

function print_example() {
  cat <<EOF
<?xml version="1.0" encoding="UTF-8" ?>
<scenario xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          xsi:noNamespaceSchemaLocation="https://raw.githubusercontent.com/hivemq/device-simulator/master/src/main/resources/scenario.xsd">
    <brokers>
        <broker id="b1">
            <address>broker.hivemq.com</address>
            <port>1883</port>
        </broker>
    </brokers>
    <clientGroups>
        <clientGroup id="cg1">
            <clientIdPattern>A[0-9]{4}</clientIdPattern>
            <count>100</count>
            <mqtt>
                <version>5</version>
            </mqtt>
        </clientGroup>
    </clientGroups>
    <topicGroups>
        <topicGroup id="tg1">
            <topicNamePattern>topic/subtopic-[0-9]</topicNamePattern>
            <count>10</count>
        </topicGroup>
    </topicGroups>
    <subscriptions>
        <subscription id="sub-1">
            <topicGroup>tg1</topicGroup>
            <wildCard>false</wildCard>
        </subscription>
    </subscriptions>
    <stages>
        <stage id="s1" expectedDuration="20s">
            <lifeCycle id="s1.l1" clientGroup="cg1">
                <rampUp duration="10s"/>
                <connect/>
                <subscribe subscription="sub-1" expectedDuration="50ms"/>
                <disconnect/>
            </lifeCycle>
        </stage>
    </stages>
</scenario>
EOF
}

if [[ $# == 0 ]]; then
  usage
  exit 0
fi

### Defaults
IMAGE=hivemq/device-simulator
NAMESPACE=default
AGENT_COUNT=3
LOG_LEVEL=INFO

MEMORY=1G
CPU=500m

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
  -s | --scenario)
    SCENARIO="$2"
    NOARG=false
    shift # past argument
    shift # past value
    ;;
  -l | --label)
    LABEL="$2"
    NOARG=false
    shift # past argument
    shift # past value
    ;;
  -a | --agent-count)
    AGENT_COUNT="$2"
    NOARG=false
    shift # past argument
    shift # past value
    ;;
  -i | --image)
    IMAGE="$2"
    NOARG=false
    shift # past argument
    shift # past value
    ;;
  -L | --log-level)
    LOG_LEVEL="$2"
    NOARG=false
    shift # past argument
    shift # past value
    ;;
  -n | --namespace)
    NAMESPACE="$2"
    NOARG=false
    shift # past argument
    shift # past value
    ;;
  --mem)
    MEMORY="$2"
    NOARG=false
    shift # past argument
    shift # past value
    ;;
  --cpu)
    CPU="$2"
    NOARG=false
    shift # past argument
    shift # past value
    ;;
  --enable-monitoring)
    MONITORING=true
    NOARG=false
    shift # past argument with no value
    ;;
  --debug)
    DEBUG=true
    shift # past argument with no value
    ;;
  -A | --all-logs)
    SHOW_ALL_LOGS=true
    shift # past argument with no value
    ;;
  -d | --detach)
    DETACH=true
    NOARG=false
    shift # past argument with no value
    ;;
  --rbac)
    RBAC_RULES=true
    NOARG=false
    shift # past argument with no value
    ;;
  help | -h | --help)
    if [[ $COMMAND == "run" ]]; then
      usage_run
    elif [[ $COMMAND == "example" ]]; then
      print_example
    elif [[ $COMMAND == "log" || $COMMAND == "show" || $COMMAND == "abort" ]]; then
      usage_misc $COMMAND
    else
      usage
    fi
    exit 0
    shift
    ;;
  *)
    POSITIONAL+=("$1") # save it in an array for later
    if [[ "$1" == "run" ]]; then
      COMMAND="run"
    fi
    if [[ "$1" == "example" ]]; then
      COMMAND="example"
    fi
    if [[ "$1" == "log" || "$1" == "logs" ]]; then
      COMMAND="log"
    fi
    if [[ "$1" == "show" ]]; then
      COMMAND="show"
    fi
    if [[ "$1" == "abort" ]]; then
      COMMAND="abort"
    fi
    if [[ "$1" == "jobs" ]]; then
      COMMAND="jobs"
    fi
    shift # past argument
    ;;
  esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters

if [[ -z "${KUBECTL_CMD}" ]]; then
  KUBECTL_CMD="kubectl"
fi
KUBECTL_OPTS="$KUBECTL_OPTS -n=${NAMESPACE}"

if [[ $DEBUG == true ]]; then
  echo "SCENARIO: $SCENARIO"
  echo "LABEL: $LABEL"
  echo "IMAGE: $IMAGE"
  echo "AGENT_COUNT: $AGENT_COUNT"
  echo "MONITORING: $MONITORING"
  echo "DETACH: ${DETACH}"
  echo ""
  echo "POSITIONAL: ${POSITIONAL[*]}"
  echo "COMMAND: ${COMMAND}"
  echo "NOARG: ${NOARG}"
  echo ""
  echo "KUBECTL_CMD: ${KUBECTL_CMD}"
  echo "KUBECTL_OPTS: ${KUBECTL_OPTS}"
  echo "PATH: $0"
  set -o xtrace
fi

function shutdown() {
  echo "Cleaning up for run ${LABEL}"
  # Continue on errors here, we will exit soon anyway.
  set +e
  eval ${KUBECTL_CMD} ${KUBECTL_OPTS} delete "configmap/${LABEL}"
  eval ${KUBECTL_CMD} ${KUBECTL_OPTS} delete pod --selector="device-simulator-task=${LABEL}"
  # Monitoring cleanup, suppress errors
  eval ${KUBECTL_CMD} ${KUBECTL_OPTS} delete service --selector="device-simulator-task=${LABEL}" || true 2>/dev/null
  trap - SIGINT SIGTERM ERR # clear the trap
  kill -- 0                 # Sends SIGTERM to child/sub processes
}

function apply_monitoring() {
    cat << EOF | eval ${KUBECTL_CMD} ${KUBECTL_OPTS} apply -f - || true 2>/dev/null
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  labels:
    app: device-simulator
  name: device-simulator-monitoring
spec:
  endpoints:
    - port: metrics
      interval: 5s
  selector:
    matchLabels:
      app: device-simulator
EOF
}

if [[ ${COMMAND} == "example" ]]; then
  print_example
  exit 0
fi

if [[ ${COMMAND} == "run" && -z ${SCENARIO} && ${NOARG} == "false" ]]; then
  echo "Error: Scenario must be specified"
  exit 1
elif [[ ${COMMAND} == "run" && -z ${SCENARIO} ]]; then
  usage_run
  exit 0
fi

if [[ ${COMMAND} == "abort" && -z ${LABEL} && ${NOARG} == "false" ]]; then
  echo "Error: Label must be specified"
  exit 1
elif [[ ${COMMAND} == "abort" && -z ${LABEL} ]]; then
  usage_misc ${COMMAND}
elif [[ ${COMMAND} == "abort" ]]; then
  echo "Aborting scenario with label ${LABEL}"
  shutdown
fi

if [[ ${COMMAND} == "log" && -z ${LABEL} && ${NOARG} == "false" ]]; then
  echo "Error: Label must be specified"
  exit 1
elif [[ ${COMMAND} == "log" && -z ${LABEL} ]]; then
  usage_misc ${COMMAND}
elif [[ ${COMMAND} == "log" ]]; then
  # Wait may not be present on older kubectl versions, so skip it if it fails
  eval ${KUBECTL_CMD} wait ${KUBECTL_OPTS} --for=condition=Ready --timeout=5m "po/device-simulator-commander-${LABEL}" || true
  if [[ ${SHOW_ALL_LOGS} == "true" ]]; then
    eval ${KUBECTL_CMD} logs ${KUBECTL_OPTS} -f -l "device-simulator-task=${LABEL}"
  else
    eval ${KUBECTL_CMD} logs ${KUBECTL_OPTS} -f "device-simulator-commander-${LABEL}"
  fi
  exit 0
fi

if [[ ${COMMAND} == "show" && -z ${LABEL} && ${NOARG} == "false" ]]; then
  echo "Error: Label must be specified"
  exit 1
elif [[ ${COMMAND} == "show" && -z ${LABEL} ]]; then
  usage_misc ${COMMAND}
elif [[ ${COMMAND} == "show" ]]; then
  # eval makes this templated command a really fun one...
  # shellcheck disable=SC2016
  # shellcheck disable=SC1083
  eval ${KUBECTL_CMD} ${KUBECTL_OPTS} get -o \'go-template={{range \$key, \$value := .data}} {{ \$value }} {{end}}\' configmap/${LABEL}
  exit 0
fi

if [[ ${COMMAND} == "jobs" ]]; then
  eval ${KUBECTL_CMD} ${KUBECTL_OPTS} get --selector="device-simulator-task" configmap
  exit 0
fi

function get_pod_template() {
  if [[ ${RBAC_RULES} == "true" ]]; then
    SERVICE_ACCOUNT_OPTIONAL="  serviceAccount: hivemq-device-simulator
  serviceAccountName: hivemq-device-simulator"
  fi

  if [[ -z "${POD_TEMPLATE}" ]]; then
    cat << EOF
apiVersion: v1
kind: Pod
metadata:
  name: "device-simulator-commander-${LABEL}"
  namespace: "${NAMESPACE}"
  labels:
    app: device-simulator
    device-simulator-task: "${LABEL}"
spec:
  containers:
    - name: commander
      args:
        - k8s
      image: "${IMAGE}"
      imagePullPolicy: Always
      env:
        - name: SIMULATOR_SCENARIO
          value: "/app/scenario/$(basename ${SCENARIO})"
        - name: ROLE
          value: COMMANDER
        - name: POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        - name: LOG_LEVEL
          value: "${LOG_LEVEL}"
        - name: AGENT_COUNT
          value: "${AGENT_COUNT}"
        - name: PLUGIN_PATH
          value: "/plugins"
        - name: MONITORING
          value: "${MONITORING}"
      resources:
        limits:
          cpu: 6
          memory: 8192M
        requests:
          cpu: ${CPU}
          memory: ${MEMORY}
      ports:
        - containerPort: 8080
          name: rest
          protocol: TCP
      volumeMounts:
        - mountPath: /app/scenario
          name: scenario
${SERVICE_ACCOUNT_OPTIONAL}
  restartPolicy: Never
  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: device-simulator-task
            operator: In
            values:
              - ${LABEL}
        topologyKey: "kubernetes.io/hostname"
      - labelSelector:
          matchExpressions:
          - key: app
            operator: In
            values:
              - hivemq
        topologyKey: "kubernetes.io/hostname"
  volumes:
    - name: scenario
      configMap:
        name: "${LABEL}"
EOF
  else
    eval "echo \"$(sed 's/"/\\"/g' ${POD_TEMPLATE})\""
  fi
}

function get_rbac_rules() {
if [[ -z "${RBAC_TEMPLATE}" ]]; then
    cat << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: hivemq-device-simulator
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: hivemq-device-simulator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
  - kind: ServiceAccount
    name: hivemq-device-simulator
    namespace: ${NAMESPACE}
EOF
  else
    eval "echo \"$(sed 's/"/\\"/g' ${RBAC_TEMPLATE})\""
  fi
}

if [[ ${COMMAND} == "run" ]]; then
  if [[ -z ${LABEL} ]]; then
    LABEL=$(date +%s)
  fi
  # Make sure we clean up
  trap shutdown SIGINT SIGTERM ERR
  echo "Running scenario at ${SCENARIO} with label ${LABEL}"

  eval ${KUBECTL_CMD} ${KUBECTL_OPTS} create configmap --from-file="${SCENARIO}" "${LABEL}"
  eval ${KUBECTL_CMD} ${KUBECTL_OPTS} label configmap "${LABEL}" "device-simulator-task=${LABEL}"
  if [[ ${DEBUG} ]]; then
    echo "Using pod template:"
    get_pod_template
  fi

  if [[ ${RBAC_RULES} == "true" ]]; then
    echo "Creating RBAC rules"
    get_rbac_rules | eval ${KUBECTL_CMD} ${KUBECTL_OPTS} apply -f -
  fi

  get_pod_template | eval ${KUBECTL_CMD} ${KUBECTL_OPTS} apply -f -

  if [[ ${DETACH} == "true" ]]; then
    echo "Running test with label ${LABEL} in the background"
    exit 0
  else
    if [[ ${MONITORING} == "true" ]]; then
      apply_monitoring
    fi
    echo "Waiting for commander pod"
    # TODO this could also be a get pods check instead
    sleep 4
    eval ${KUBECTL_CMD} wait ${KUBECTL_OPTS} --for=condition=Ready --timeout=5m "po/device-simulator-commander-${LABEL}"

    if [[ ${SHOW_ALL_LOGS} == "true" ]]; then
      eval ${KUBECTL_CMD} logs --max-log-requests="10" ${KUBECTL_OPTS} -f -l "device-simulator-task=${LABEL}" || true
    else
      eval ${KUBECTL_CMD} logs ${KUBECTL_OPTS} -f "device-simulator-commander-${LABEL}" || true
    fi
    shutdown
  fi
fi

if [[ -z ${COMMAND} ]]; then
  usage
fi