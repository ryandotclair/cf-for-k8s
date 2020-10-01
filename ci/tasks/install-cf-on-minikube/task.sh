#!/bin/bash
set -eou pipefail

source cf-for-k8s-ci/ci/helpers/auth-to-gcp.sh

echo "Generating install values..."
cf-for-k8s/hack/generate-values.sh -d vcap.me -g gcp-service-account.json > cf-install-values/cf-install-values.yml
cat <<EOT >> cf-install-values/cf-install-values.yml
enable_automount_service_account_token: true
remove_resource_requirements: true
use_first_party_jwt_tokens: true

EOT

echo "Uploading cf-for-k8s repo..."
gcloud beta compute \
  scp --recurse cf-for-k8s ${user_host}:/tmp/minikube/ --compress \
  --zone "us-central1-a" > /dev/null

echo "Replacing CI directory..."
gcloud beta compute \
  scp --recurse cf-for-k8s-ci/ci ${user_host}:/tmp/minikube/cf-for-k8s/ --compress \
  --zone "us-central1-a" > /dev/null

echo "Uploading cf-install-values.yml..."
gcloud beta compute \
  scp cf-install-values/cf-install-values.yml ${user_host}:/tmp \
  --zone "us-central1-a" > /dev/null

cat <<EOT > remote-install-cf.sh
#!/usr/bin/env bash
set -euo pipefail

export HOME=/tmp/minikube
export PATH="/tmp/minikube/bin:/tmp/minikube/go/bin:\$PATH"

CF_VALUES=/tmp/cf-install-values.yml
CF_RENDERED=/tmp/cf-rendered.yml
cd /tmp/minikube/cf-for-k8s
ytt -f config -f \$CF_VALUES > \$CF_RENDERED

eval "\$(minikube docker-env)"
kapp deploy -f \$CF_RENDERED -a cf -y
EOT

chmod +x remote-install-cf.sh

echo "Uploading remote-install-cf.sh..."
gcloud beta compute \
  scp remote-install-cf.sh ${user_host}:/tmp \
  --zone "us-central1-a" > /dev/null

sleep 100000

echo "Running remote-install-cf.sh..."
gcloud beta compute \
  ssh ${user_host} \
  --command "/tmp/remote-install-cf.sh" \
  --zone "us-central1-a"
