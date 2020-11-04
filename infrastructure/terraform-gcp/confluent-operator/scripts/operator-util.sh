#!/usr/bin/env sh

set -o pipefail
set +o xtrace

red=$(tput setaf 1)
green=$(tput setaf 2)
reset=$(tput sgr0)

function os_type() {
    OS=${OSTYPE//[0-9.-]*/}
    case "$OS" in
        darwin) machine=Mac ;;
        linux)  machine=Linux ;;
        *)
        echo "Operating System $OSTYPE not supported, supported types are darwin, linux"
        exit 1
        ;;
    esac
}

## Find OS type
os_type

function program_is_installed() {
  local return_=0
  # set to 1 if not found
  type $1 >/dev/null 2>&1 || return_=1;
  # return value
  return ${return_}
}

function echo_fail() {
  printf "\e[31m✘ ${1}"
  printf "\033\e[0m\n"
}

function echo_pass {
  printf "\e[32m✔ ${1}"
  printf "\033\e[0m\n"
}

function die {
    echo "${red}$@${reset}"
    exit 1
}

function check_binaries() {
    local v=$1
    program_is_installed ${v} || die "\nPlease install [$v] before running the script...\n"
}

function validate_k8s() {
    echo "Validating if kubernetes cluster is accessible from local machine: \n"
    kubectl --request-timeout='5' version &> /dev/null || die "\tKubernetes cluster access: $(echo_fail) \n"
    echo "\tKubernetes cluster access: $(echo_pass) \n"
}

function validate_helm() {
    echo "Validating if Helm is accessible from local machine: \n"
    helm version &> /dev/null || die "\tHelm access: $(echo_fail) \n\tPlease refer to the Operator"\
                                      " documentation for Helm troubleshooting."
    echo "\tHelm access: $(echo_pass) \n"
}

function validate_context() {
    if [[ -z "${context}" ]]; then
        context=$(kubectl config current-context 2> /dev/null)
        [[ $? != 0 || -z "${context}" ]] && die "\t${red}No current kubernetes context found.${reset}"
    else
        kubectl config get-contexts ${context} &> /dev/null || \
            die "Kubernetes context ${context} not found in config."
    fi
}

function validate_namespace() {
    if [[ -z "${namespace}" ]]; then
        namespace=$(kubectl --context ${context} config view --minify | grep namespace | sed "s/namespace://g" | sed "s/ //g")
        [[ -z "${namespace}" ]] && \
                 die "\t${red}Kubernetes namespace does not exists in ${context} context. Either pass one or set the "\
                 "namespace by running \n\t'kubectl config set-context --current --namespace=<insert-namespace-name-here>'."\
                 "${reset}"
    else
        kubectl --context ${context} get namespace ${namespace} &> /dev/null || run_cmd "kubectl create namespace ${namespace}" "${verbose}"
    fi

    echo "\tKubernetes Namespace:  $(echo_pass ${namespace})"
}

function required_binaries() {
    echo "\nChecking if required executables are installed:\n"
    printf "\tKubectl command installation: "
    check_binaries kubectl && echo_pass
    printf "\tHelm command Installation: "
    check_binaries helm && echo_pass
    printf "\tprintf command Installation: "
    check_binaries printf && echo_pass
    printf "\tawk command Installation: "
    check_binaries awk && echo_pass
    printf "\tcut command Installation: "
    check_binaries cut && echo_pass
}

function contains() {
  local check=$1 && shift
  local a=($@)
  local in=1
  for i in ${a[@]}; do
    if [[ "$check" = "$i" ]]; then
      in=0
    fi
  done
  return ${in}
}

function helm_folder_path() {
  local DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
  echo $(printf "%s/../helm/confluent-operator" ${DIR})
}

function retry() {
  local retries=$1
  shift
  local count=0
  until "$@"; do
    exit=$?
    wait=$((2 ** $count))
    count=$(($count + 1 ))
    if [[ ${count} -lt ${retries} ]]; then
      echo "Retry $count/$retries exited ${exit}, retrying in ${wait}  seconds..."
      sleep ${wait}
    else
      echo "Retry $count/$retries exited ${exit}, no more retries left."
      exit 1
      return 1
    fi
  done

  return 0
}

function run_cmd() {
  enable_debug=$2
  echo "Run Command:\n"
  echo "\t${green}$1${reset}\n"
  if [[ ${enable_debug} = "true" ]]; then
    eval $1
  else
    val=$(eval $1 2>&1)
  fi
  if [[ $? != 0 ]]; then
      die "${red}Unable to execute ${1} ${val} ${reset}\n"
  fi
}

function run_helm_command() {

  local script_path="$1"
  local service="$2"
  local helm_basedir=$(helm_folder_path)
  local helm_version
  helm_version=$(get_helm_version) || { echo ${helm_version}; exit 1; }
  if [[ ${upgrade} == "true" ]]; then
     operator=$(printf "helm --kube-context ${context} upgrade --install -f %s %s %s %s --namespace %s" "${script_path}" "${helm_args}" "${service}" "${helm_basedir}" "${namespace}")
  else
     if [[ "${helm_version}" == "v2" ]]; then
        operator=$(printf "helm --kube-context ${context} install -f %s --name %s %s --namespace %s %s" "${script_path}" "${service}" "${helm_basedir}" "${namespace}" "${helm_args}")
     elif [[ "${helm_version}" == "v3" ]]; then
        operator=$(printf "helm --kube-context ${context} install -f %s %s %s --namespace %s %s" "${script_path}" "${service}" "${helm_basedir}" "${namespace}" "${helm_args}")
     fi
  fi
  echo "$operator"
}

function wait_for_k8s_sts() {
  local kubectl_cmd="kubectl --context ${context} -n ${namespace}"

  retry ${retries} kubectl -n ${namespace} --context ${context} get sts ${sts_name}
  run_cmd "${kubectl_cmd} rollout status sts/${sts_name} -w" ${verbose}
}

function run_cp() {

  local helm_file_path="$1"
  local helm_version
  helm_version=$(get_helm_version) || { echo ${helm_version}; exit 1; }
  local helm_common_args
  if [[ "${helm_version}" == "v2" ]]; then
    helm_common_args="--wait --timeout 600"
  elif [[ "${helm_version}" == "v3" ]]; then
    helm_common_args="--wait --timeout 600s"
  fi
  local kubectl_cmd="kubectl --context ${context} -n ${namespace}"

  kubectl --context ${context} -n ${namespace} get sa default -oyaml | grep "confluent-docker-registry"  2>&1 > /dev/null
  if [[ $? != 0 ]]; then
    run_cmd "${kubectl_cmd} patch serviceaccount default -p '{\"imagePullSecrets\": [{\"name\": \"confluent-docker-registry\" }]}'" ${verbose}
  fi

  ## Operator
  helm_args="--set operator.enabled=true ${helm_common_args}"
  run_cmd "$(run_helm_command ${helm_file_path} "${release_prefix}-operator")" ${verbose}

  ## Zookeeper
  helm_args="--set zookeeper.enabled=true ${helm_common_args}"
  run_cmd "$(run_helm_command ${helm_file_path} "${release_prefix}-zk")" ${verbose}
  sts_name=$(kubectl --context ${context} -n ${namespace} get zookeeperclusters.cluster.confluent.com -l component=zookeeper -o jsonpath='{.items[*].metadata.name}')
  wait_for_k8s_sts

  ## Kafka
  helm_args="--set kafka.enabled=true ${helm_common_args}"
  run_cmd "$(run_helm_command ${helm_file_path} "${release_prefix}-kafka")" ${verbose}
  sts_name=$(kubectl --context ${context} -n ${namespace} get kafkaclusters.cluster.confluent.com -l component=kafka -o jsonpath='{.items[*].metadata.name}')
  wait_for_k8s_sts

  ## SchemaRegistry/connect/replicator/controlcenter/ksql
  helm_args="--set connect.enabled=true,schemaregistry.enabled=true,replicator.enabled=true,controlcenter.enabled=true,ksql.enabled=true ${helm_common_args}"
  run_cmd "$(run_helm_command ${helm_file_path} "${release_prefix}-sr-replicator-connect-c3")" ${verbose}
  echo "\t${green}KSQL, Schema Registry, Control Center, Replicator and Connect are being deployed and will be up soon.${reset}"
  sts_name=$(kubectl --context ${context} -n ${namespace} get psc -l component=ksql -o jsonpath='{.items[*].metadata.name}')
  wait_for_k8s_sts
  sts_name=$(kubectl --context ${context} -n ${namespace} get psc -l component=schemaregistry -o jsonpath='{.items[*].metadata.name}')
  wait_for_k8s_sts
  sts_name=$(kubectl --context ${context} -n ${namespace} get psc -l component=replicator -o jsonpath='{.items[*].metadata.name}')
  wait_for_k8s_sts
  sts_name=$(kubectl --context ${context} -n ${namespace} get psc -l component=controlcenter -o jsonpath='{.items[*].metadata.name}')
  wait_for_k8s_sts
  sts_name=$(kubectl --context ${context} -n ${namespace} get psc -l component=connect -o jsonpath='{.items[*].metadata.name}')
  wait_for_k8s_sts
}

function get_helm_version() {
    local helm_version=$(helm version -c --short | awk '{print $NF}' | cut -f1 -d'.')
    if [[ "${helm_version}" != "v2" && "${helm_version}" != "v3" ]]; then
        echo "Helm is neither version v2 or v3, found version ${helm_version}"
        return 1
    fi
    echo "${helm_version}"
}

function cp_delete() {
  if  [[ ! -z ${delete} ]] && [[ ${delete} = "1" ]]; then
     local helm_version
     helm_version=$(get_helm_version) || { echo ${helm_version}; exit 1; }
     echo "Delete CP deployment:\n"
        local array=(${release_prefix}-sr-replicator-connect-c3 ${release_prefix}-kafka ${release_prefix}-zk ${release_prefix}-operator)
        for release in "${array[@]}"; do
            if helm --kube-context ${context} --namespace ${namespace} ls | grep -qF "${release}"; then
              if [[ "${release}" = "${release_prefix}-operator" ]]; then
                sleep 20s
                run_cmd "kubectl delete pod --context ${context} -l clusterId=${namespace} -n ${namespace} --force --grace-period 0" ${verbose}
              fi
              if [[ "${helm_version}" == "v2" ]]; then
                run_cmd "helm --kube-context ${context} delete --purge ${release}" ${verbose}
              elif [[ "${helm_version}" == "v3" ]]; then
                run_cmd "helm --kube-context ${context} --namespace ${namespace} uninstall ${release}" ${verbose}
              fi
              sleep 10s
            else
              echo "\tValidation of Helm release [${green}$release${reset}] availability: $(echo_fail)\n"
            fi
        done
    exit
  fi
}

function usage() {
    echo "usage: ./operator-util.sh -r <release_prefix> -f <helm yaml>"
    echo "   ";
    echo "  -n | --namespace       : kubernetes namespace to use, by default, uses the current context's namespace if present (optional)";
    echo "  -c | --context         : kubernetes context to use, by default, uses the current context (optional)";
    echo "  -d | --delete          : delete helm release";
    echo "  -f | --helm-file       : provide helm chart's values.yaml file, e.g /tmp/values.yaml";
    echo "  -r | --release-prefix  : release name prefix (required)";
    echo "  -v | --verbose         : enable verbose logging";
    echo "  -u | --upgrade         : Upgrade Confluent Platform";
    echo "  -e | --retries         : retries for kubernetes resources, default 10 times with exponential backoff";
    echo "  -h | --help            : Usage command";
}

function parse_args {
    args=()
    while [[ "$1" != "" ]]; do
        case "$1" in
            -c | --context )              context="${2}";            shift;;
            -n | --namespace )            namespace="${2}";          shift;;
            -d | --delete)                delete="1";                ;;
            -r | --release-prefix)        release_prefix="${2}";     shift;;
            -f | --helm-file)             values_file="${2}";        shift;;
            -e | --retry )                retries="${2}";            shift;;
            -u | --upgrade )              upgrade="true";            ;;
            -v | --verbose )              verbose="true";            ;;
            -h | --help )                 help="true";               shift;;
            * )                           args+=("$1")
        esac
        shift
    done

    set -- "${args[@]}"

    if [[ ! -z ${help} ]]; then
      usage
      exit
    fi

    if [[ -z ${release_prefix} ]]; then
        usage
        die "Please provide a prefix for the helm release name"
    fi

    # set verbose logging
    if [[ -z ${verbose} ]]; then
       verbose="false"
    fi

    # set upgrade
    if [[ -z ${upgrade} ]]; then
        upgrade="false"
    fi

    ## retry states
    if [[ -z ${retries} ]]; then
        retries=10
    fi
}

function run() {
  parse_args "$@"

  echo "\nConfluent Platform Deployment:\n"

  required_binaries

  validate_k8s

  validate_helm

  validate_context

  validate_namespace

  [[ -z  ${values_file} || ! -f ${values_file} ]] && die "\tHelm file ${values_file} does not exist: $(echo_fail)\n
                                                          \tPass in a valid helm file."

  cp_delete
  run_cp ${values_file}
}

run "$@";
