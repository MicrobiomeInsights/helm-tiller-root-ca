#!/usr/bin/env bash
#
# this script is a helpful wrapper for Helm CLI, when using TLS enabled Tiller
# See https://github.com/helm/helm/blob/master/docs/tiller_ssl.md
#
# Copyright (C) 2019 Anastas Dancha (aka @anapsix)
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
#
# save this somewhere in your PATH (e.g. /usr/local/bin/)
# as helm_tls_wrapper.sh
# and add shell alias (so that shell-completion works without any additional changes)
# alias helm=helm_tls_wrapper.sh
#
# save your TLS certificates in ${HELM_HOME}/tls/${K8S_CONTEXT}/
# as ca.pem, cert.pem, and key.pem

# my helm/tiller installation uses HTTPS only, no HTTP port is available
# and also verifys the server/client with mutual TLS 

# always use TLS, as HTTP is not available on my installation
: ${FORCE_TLS:=1}

: ${HELM_HOME:=~/.helm}
: ${KUBECONFIG:=${HOME}/.kube/config}
: ${HELM_VERSION:="unset"}
: ${TILLER_NAMESPACE:="tiller"}

if [[ "${HELM_VERSION}" == "unset" ]]; then
  HELM_BIN="helm"
else
  echo >&2 "HELM Version: ${HELM_VERSION}"
  HELM_BIN="helm_${HELM_VERSION}"
fi

K8S_CONTEXT_ARG="$(expr "$(echo "$@")" : '^.*--kube-context=\([a-zA-Z_-][a-zA-Z_-]*\)')"

if [[ -z "${K8S_CONTEXT_ARG}" ]]; then
  K8S_CONTEXT="$( awk '/^current-context:/ { print $2 }' ${KUBECONFIG} )"
else
  K8S_CONTEXT="${K8S_CONTEXT_ARG}"
fi

# if we can't find the context, ask kubernetes for the current context 
[[ -z ${K8S_CONTEXT} ]] && K8S_CONTEXT="$(kubectl config current-context)"
[[ -z ${K8S_CONTEXT} ]] && echo "ERROR: I can't seem to get the k8s context" &&  exit 1

TLS_DIR="${HELM_HOME}/tls/${K8S_CONTEXT}"

echo >&2 "K8S_CONTEXT: ${K8S_CONTEXT}"
[[ ! -z ${KUBE_CONFIG} ]] && echo >&2 "KUBE_CONFIG: ${KUBE_CONFIG}"
[[ ! -z ${TILLER_NAMESPACE} ]] && echo >&2 "TILLER_NAMESPACE: ${TILLER_NAMESPACE}" 

for arg in $@; do
  if [[ ${FORCE_TLS} == 1 || "$arg" == "--tls" ]]; then
    export HELM_TLS_CA_CERT="${TLS_DIR}/ca.pem"
    export HELM_TLS_CERT="${TLS_DIR}/cert.pem"
    export HELM_TLS_KEY="${TLS_DIR}/key.pem"
    export HELM_TLS_ENABLE="true"
    export HELM_TLS_VERIFY="true"
    export TILLER_NAMESPACE=${TILLER_NAMESPACE}

    if [[ "$DEBUG" == "1" ]]; then
      [[ ! -z ${HELM_TLS_CA_CERT} ]] && echo export HELM_TLS_CA_CERT=\"${HELM_TLS_CA_CERT}\"
      [[ ! -z ${HELM_TLS_CERT} ]]    && echo export HELM_TLS_CERT=\"${HELM_TLS_CERT}\"
      [[ ! -z ${HELM_TLS_KEY} ]]     && echo export HELM_TLS_KEY=\"${HELM_TLS_KEY}\"
      [[ ! -z ${HELM_TLS_ENABLE} ]]  && echo export HELM_TLS_ENABLE=\"${HELM_TLS_ENABLE}\"
      [[ ! -z ${HELM_TLS_VERIFY} ]]  && echo export HELM_TLS_VERIFY=\"${HELM_TLS_VERIFY}\"
      [[ ! -z ${TILLER_NAMESPACE} ]] && echo export TILLER_NAMESPACE=\"${TILLER_NAMESPACE}\"
    fi
    break
  fi
done

[[ "$DEBUG" == "1" ]] && echo ${HELM_BIN} $@ || ${HELM_BIN} $@
