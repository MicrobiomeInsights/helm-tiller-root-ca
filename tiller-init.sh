#!/bin/bash

#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

TILLER_NAMESPACE="tiller"
TILLER_SERVICE_ACCOUNT="tiller"

kubectl create namespace ${TILLER_NAMESPACE}
kubectl create serviceaccount -n ${TILLER_NAMESPACE} ${TILLER_SERVICE_ACCOUNT}

kubectl create clusterrolebinding tiller-cluster-admin --clusterrole=cluster-admin --serviceaccount="${TILLER_NAMESPACE}:${TILLER_SERVICE_ACCOUNT}"


## 
## EXIT.  This is not working with the new pki layout yet
##

exit 0 

CA_CERT=pki/ca/intermediate/certs/ca-chain.cert.pem

# need to get the latest server cert 
TILLER_KEY=pki/tiller/private/tiller.key.pem
TILLER_CERT=pki/tiller/tiller.cert.pem


#helm init --dry-run --debug \
helm init \
    --tiller-namespace ${TILLER_NAMESPACE} \
	--service-account ${TILLER_SERVICE_ACCOUNT} \
	--tiller-tls \
	--tiller-tls-cert $TILLER_CERT \
	--tiller-tls-key $TILLER_KEY \
	--tiller-tls-verify \
	--tls-ca-cert $CA_CERT
