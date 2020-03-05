#!/bin/bash

set -ex
SCRIPT_DIR="$(realpath "$(dirname "$0")")"
PROJECT_ROOT_DIR="$(dirname "${SCRIPT_DIR}")"
SPECS_DIR="${PROJECT_ROOT_DIR}/specs"

PV_NAME_PREFIX=${PV_NAME_PREFIX:-cassandra-data}
if [[ $# -lt 2 ]]; then
  echo "Usage:" >&2
  echo "  $0 <create|delete> <number of persistent volumes to create>" >&2
  exit 1
fi

if [[ "create" = "${1}" ]];


for i in $(seq ${2}); do
    PV_NAME="${PV_NAME_PREFIX}-${i}"

    echo "Creating namespace $NAMESPACE"
    sed 's|SPARK_NAMESPACE|'"${NAMESPACE}"'|g' ${TEMPLATES_DIR}/namespace.tmpl | kubectl apply -f -
    sed 's|SERVICE_ACCOUNT_NAME|'"${SERVICE_ACCOUNT_NAME}"'|g' ${TEMPLATES_DIR}/service-account.tmpl | kubectl apply --namespace "${NAMESPACE}" -f -

    kubectl kudo --namespace "${NAMESPACE}" install --instance "${INSTANCE_NAME_PREFIX}-${i}" "${OPERATOR_DIR}" \
            -p operatorVersion="${OPERATOR_VERSION}" \
            -p sparkServiceAccountName="${SERVICE_ACCOUNT_NAME}" \
            -p createSparkServiceAccount=false

    kubectl wait  --for=condition=Available deployment --all  --namespace "$NAMESPACE" --timeout=120s
done