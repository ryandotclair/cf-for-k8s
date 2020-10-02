#!/bin/bash
set -eou pipefail

source cf-for-k8s-ci/ci/helpers/auth-to-gcp.sh
user_host="root@${vm_name}"

cat <<EOT > remote-check-permissions.sh
while [[ ! -w /tmp/minikube ]]; do
  echo "Waiting for write access to /tmp/minikube..."
  sleep 5
done
EOT
chmod +x remote-check-permissions.sh

echo "Uploading remote-check-permissions.sh..."
gcloud beta compute \
  scp remote-check-permissions.sh ${user_host}:/tmp/ \
  --zone "us-central1-a" > /dev/null

echo "Running remote-check-permissions.sh..."
gcloud beta compute \
  ssh ${user_host} \
  --command "/tmp/remote-check-permissions.sh" \
  --zone "us-central1-a"

cat <<EOT > remote-create-minikube-cluster.sh
#!/usr/bin/env bash
set -euo pipefail

export HOME=/tmp/minikube
export PATH=/tmp/minikube/bin:/tmp/minikube/go/bin:$PATH
minikube start --cpus=14 --memory=32g --driver=virtualbox
minikube addons enable metrics-server
EOT
chmod +x remote-create-minikube-cluster.sh

echo "Uploading remote-create-minikube-cluster.sh..."
gcloud beta compute \
  scp remote-create-minikube-cluster.sh ${user_host}:/tmp/ \
  --zone "us-central1-a" > /dev/null

echo "Running remote-create-minikube-cluster.sh..."
gcloud beta compute \
  ssh ${user_host} \
  --command "/tmp/remote-create-minikube-cluster.sh" \
  --zone "us-central1-a"
