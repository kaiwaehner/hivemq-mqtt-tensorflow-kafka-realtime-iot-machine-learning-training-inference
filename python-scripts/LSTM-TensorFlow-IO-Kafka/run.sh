#!/usr/bin/env bash

set -eo pipefail

IMAGE=${IMAGE:-sbaier1/car-sensor-model:latest}
MODEL_NAME=${MODEL_NAME:-model1.h5}

echo "Running model training with image ${IMAGE}, writing to ${MODEL_NAME}"

cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: "sensor-model-training"
spec:
  restartPolicy: Never
  containers:
    - name: training
      image: ${IMAGE}
      imagePullPolicy: Always
      command: ["python3"]
      args: ["cardata-v2.py", "kafka.operator.svc.cluster.local:9071", "SENSOR_DATA_S_AVRO", "0", "model-predictions", "train", "${MODEL_NAME}"]
      volumeMounts:
        - name: storage-secret
          mountPath: /credentials
          readOnly: true
  volumes:
    - name: storage-secret
      secret:
        secretName: google-application-credentials
EOF

kubectl wait --for=condition=Ready --timeout=5m po/sensor-model-training
kubectl logs -f po/sensor-model-training
kubectl delete po/sensor-model-training

echo "Creating prediction deployment"
cat << EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: tf-model
  namespace: default
spec:
  selector:
    matchLabels:
      app: tensorflow
  template:
    metadata:
      labels:
        app: tensorflow
    spec:
      nodeSelector:
        failure-domain.beta.kubernetes.io/zone: europe-west1-b
      containers:
        - name: model
          image: ${IMAGE}
          imagePullPolicy: Always
          command: ["python3"]
          args: ["cardata-v2.py", "kafka.operator.svc.cluster.local:9071", "SENSOR_DATA_S_AVRO", "0", "model-predictions", "predict", "${MODEL_NAME}"]
          volumeMounts:
          - name: storage-secret
            mountPath: /credentials
            readOnly: true
      volumes:
        - name: storage-secret
          secret:
            secretName: google-application-credentials
EOF