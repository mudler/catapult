#!/usr/bin/env bash

. scripts/include/common.sh
. .envrc

set -exuo pipefail

if [ "${EMBEDDED_UAA}" != "true" ]; then
    if helm ls 2>/dev/null | grep -qi susecf-uaa ; then
        helm del --purge susecf-uaa
    fi
    if kubectl get namespaces 2>/dev/null | grep -qi uaa ; then
        kubectl delete namespace uaa
    fi
fi

if helm ls 2>/dev/null | grep -qi susecf-scf ; then
    helm del --purge susecf-scf
fi
if kubectl get namespaces 2>/dev/null | grep -qi scf ; then
    kubectl delete namespace scf
fi

if [[ $ENABLE_EIRINI == true ]] ; then
    if kubectl get namespaces 2>/dev/null | grep -qi eirini ; then
        kubectl delete namespace eirini
    fi
    if helm ls 2>/dev/null | grep -qi metrics-server ; then
    helm del --purge metrics-server
    fi
fi

rm -rf scf-config-values.yaml chart.zip helm kube "$HELM_HOME" "$CF_HOME"
