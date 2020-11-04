# Tiller Service Account Custom Roles

The provided YAML files allow you to create a Tiller service account with the minimum set of k8 privileges. Note: These templates may not cover everything you may need, so you can append to the existing set of rules if need be.

### cluster-admin Clusterrole Alternative
`clusterrole-minimum.yaml` has the minimum set of privileges necessary to deploy Operator. If you don't want to use the cluster-admin clusterrole, you can substitute it with this to deploy Operator and all of its components.

### Per-Namespace Tiller Clusterrole/Role
If you think having a cluster-admin is too insecure, this is the alternative to reduce the scope of what tiller can operate on. This option can be especially helpful if there will be many people touching the cluster. Before starting, it is strongly encouraged to have the system admin setup 2-way TLS for helm/tiller. For this option, there is an assumption that Operator as deployed but not its related components. If a Tiller service account with cluster-admin access already exists, the system admin can keep it and create a Tiller service account for only the desired namespace. Then, the system admin would use the `custom-clusterrole.yaml` template to grant that Tiller the minimum privileges to deploy the Operator components. After the service account is setup per namespace, any user who has access to that namespace can use helm/tiller to deploy Operator components, but only the sys-admin will be able to change the Tiller configuration or create new clusterroles.

### Helm Alternative
If you do not wish to rely on helm in any capacity, you can opt to use `helm template` to generate the templates for all the components you need.
