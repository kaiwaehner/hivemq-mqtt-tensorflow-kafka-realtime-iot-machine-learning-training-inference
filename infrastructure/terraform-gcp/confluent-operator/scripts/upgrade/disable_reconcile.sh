#!/bin/sh
set -e

## This will add annotation to disable the reconcilation for all the psc running on specific namespace.
## This is only required if operator ugprade brakes some backward compability problem.

namespace=$1
[ $# -ne 1 ] && { echo "Usage: $0 <namespace>, disable reconcile for all CP cluster on given <namespace>"; exit 1; }

for psc_name in $(kubectl -n "${namespace}" get psc -o custom-columns=:metadata.name  --no-headers)
do
  kubectl -n "${namespace}" annotate  --overwrite  psc "${psc_name}" physicalstatefulcluster.core.confluent.cloud/ignore='true'
done