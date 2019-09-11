#!/usr/bin/env bash

if ! hash kubectl 2>/dev/null; then
    echo "ERROR: You must install kubectl to use this script"
    exit 1
fi

echo "Running the scenario ad-hoc..."
exec ./kube-cli.sh run -s scenario.xml -l car-demo -i sbaier1/device-simulator:avro