#!/bin/sh
set -e

## This will enable reconcilation for specfic CP cluster running on specific name.
## To enable reconcilation for cluster with zookeeper name on namespace operator.
## ./enable_reconcile.sh operator zookeeper

namespace=$1
cluster_name=$2

[ $# -ne 2 ] && { echo "Usage: $0 <namespace> <cluster_name>, enable reconcile for a specifc CP <cluster> on given <namespace>"; exit 1; }
kubectl -n "${namespace}" annotate  --overwrite  psc "${cluster_name}" physicalstatefulcluster.core.confluent.cloud/ignore='false'
