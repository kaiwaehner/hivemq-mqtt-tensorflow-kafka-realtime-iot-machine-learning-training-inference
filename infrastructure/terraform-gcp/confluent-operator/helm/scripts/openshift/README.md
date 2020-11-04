# OpenShift 

Below configuration are required before running Confluent Platform (CP) through Confluent Operator. There are four different settings for SCC OpenShift configuration as follows:

1. Let OpenShift picks the randomUID for containers ( Recommended )

    The randomUID/scc.yaml file will let Openshift pick the random UID. To enable this capability, update helm charts `global.pod.randomUID=true` (`helm/confluent-operator/values.yaml` or your own override file) before deploying Confluent Platform.

2. Let OpenShift runs container with custom UID for containers

    The customUID/scc.yaml file will let you configure the custom UID configuration. To configure, make sure the project in OpenShift is configured 
    with the UID range (`oc get project operator -oyaml | grep "openshift.io/sa.scc.uid-range"`). Based on that UID range, update customUID/scc.yaml file. You also need to make sure to update `global.pod.securityContext.fsGroup` and `global.pod.securityContext.runAsUser` with same UID configured on the customUID/scc.yaml file.

3. Let OpenShift run containers with default `restricted` SCC mode.

    Require to deploy CP witout `HostPort` (it's configurable and can be disabled through helm charts) capability.
    In this case, the Openshift will use restricted SCC and you need to update helm charts  as discussed on in step 1 and no more creation of scc object. 

4. Let OpenShift run containers with root UID (Not Recommended)

    For some unknown reason, if you require to run containers as a root UID, then you need to configure `global.pod.randomUID=true` in
    the helm charts then use scc.yaml file as describe in randomUID folder with changes from `runAsUser.type: RunAsAny` and `fsGroup.type: RunAsAny`. 
    This requirement is only true for the Debian Images. For Redhat based Images this option is invalid.

# Create SCC

Change the scc.yaml file as with your security requirement.

- SecurityContextConstraints (SCC) for Openshift. Make sure to update  `users` field in `scc.yaml` 

    users:
      - system:serviceaccount:operator:default
    
   where `operator` is namespace/project name, change namespace name where confluent components are running. 
   If running on multi-namespace add each line for each namespace before running below command: 
    
        oc create -f randomUID/scc.yaml