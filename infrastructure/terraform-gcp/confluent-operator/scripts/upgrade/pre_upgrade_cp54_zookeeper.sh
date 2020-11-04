#!/bin/sh
set -e

namespace=$1
[ $# -ne 1 ] && { echo "Usage: $0 <namespace> where zookeeper cluster is running"; exit 1; }

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
snapshot_file="${DIR}/files/snapshot.0"
data_path="/mnt/data/data/version-2/"

## only try to update if the zookeeper cluster is running CP 5.3 version
for pod_name in $(kubectl -n "${namespace}" get pods -l type=zookeeper -o custom-columns=:metadata.name --no-headers)
do
  if ! kubectl -n "${namespace}" exec -it "${pod_name}" -- env | grep "CONFLUENT_VERSION=5.3"; then
      echo "==> running zookeeper cluster is not part of CP 5.3 release"
      exit
  else
    echo echo "==> running zookeeper cluster on namespace $namespace is part of CP 5.3 release..check if snapshot file exists.."
    break
  fi
done

# find all the zookeeper pods for given namespace
for pod_name in $(kubectl -n "${namespace}" get pods -l type=zookeeper -o custom-columns=:metadata.name --no-headers)
do
  if ! kubectl -n "${namespace}" exec -it "${pod_name}" sh -- -c "ls ${data_path}snapshot*" &> /dev/null; then
     kubectl cp "${snapshot_file}" "${namespace}/${pod_name}:${data_path}"
     if [ $? != 0 ]; then
       echo "==> copying snapshot.0 failed for a pod ${pod_name} in namespace ${namespace}..retry again"
       exit
     fi
     echo "==> copying snapshot.0 successful for a pod ${pod_name} in namespace ${namespace}"
  else
      echo "==> snapshot files already exist for a pod ${pod_name} in namespace ${namespace}"
  fi
done

echo "==> zookeeper cluster is ready to upgrade to CP 5.4 version"
