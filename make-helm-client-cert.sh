#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# 1 year + 10 days
DAYS=375

##
## Create Helm Client Certificates and save them into the helm directory 
## current context for helm to use 
##
## compatible with helm_tls_wrapper.sh: https://gist.github.com/brianonn/e8c8e8776c03e24bdeab49111c4436fe
## after server and client certificates are created, there is now mutual TLS between client and server.
##

# DATE and USAGE are used in the x509.env file
DATE=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
USAGE="Helm Client"

source ${DIR}/x509.env

HELMDIR="${DIR}/pki/helm/${DATE}"
mkdir -p "${HELMDIR}/private"

HELM_KEY=$HELMDIR/private/tls.key
HELM_CSR=$HELMDIR/tls.csr
HELM_CERT=$HELMDIR/tls.crt

# I had trouble with openssl not overwriting the CSR before and using an old one
# so remove everything first to start clean from multiple runs
# rm -rf $HELM_KEY $HELM_CSR $HELM_CERT

# generate a private key
openssl genrsa -out $HELM_KEY 4096
ret=$?
if [[ $ret != 0 ]]; then
    echo "Failed to generate RSA key"
    exit 1
fi 

chmod 600 $HELM_KEY

# generate a CSR - use defaults from openssl.csr.cnf
openssl req -config openssl.csr.cnf -key $HELM_KEY -new -sha256 -out $HELM_CSR -subj "$SUBJ"
ret=$?
if [[ $ret != 0 ]]; then
    echo "Failed to generate CSR file"
    exit 1
fi 

## --- NORMALLY, the CSR is sent to the CA and the CA signs it and returns the signed CERT
## --- Here, we do the CA signing step immediately

# Need to be inside the CA directory to get access to the databases there
cd "${DIR}/pki/ca/intermediate/"

# sign the CSR with the intermediate CA, generating the signed client certificate.
openssl ca \
  -config $PWD/openssl.cnf \
  -extensions usr_cert \
  -days $DAYS \
  -notext \
  -md sha256 \
  -in $HELM_CSR \
  -out $HELM_CERT

ret=$?
if [[ $ret != 0 ]]; then
    echo "Failed to generate and sign the certificate"
    exit 1
fi 

echo 
echo "created:" 
echo "  tls.key: ${HELM_KEY/$DIR\//./}"
echo "  tls.csr: ${HELM_CSR/$DIR\//./}"
echo "  tls.crt: ${HELM_CERT/$DIR\//./}"
echo 
echo -n "Do you want to apply these new client keys to your Helm Client config ? [y/N]: "
read ans
if [[ $ans =~ ^[yY](es)?$ ]]; then
    K8S_CONTEXT="$(kubectl config current-context)"
    echo "The current kubectl context is: ${K8S_CONTEXT}" 
    echo -n "Use this kubernetes context? [y/N]: "
    ans="" 
    read ans
    if [[ $ans =~ ^[yY](es)?$ ]]; then
        # copy the new client certs over to ~/.helm/tls/<context>/ to be compatible with the helm_tls_wrapper.sh
        # https://gist.github.com/brianonn/e8c8e8776c03e24bdeab49111c4436fe
        cp -pr ${HELM_KEY} $HOME/.helm/tls/${K8S_CONTEXT}/key.pem 
        cp -pr ${HELM_CERT} $HOME/.helm/tls/${K8S_CONTEXT}/cert.pem
        cp -pr ${HELM_CSR} $HOME/.helm/tls/${K8S_CONTEXT}/csr.pem

        echo " *** ALL DONE ***" 
        echo "Verify your helm configuration with 'helm ls' and 'helm ls --tls --tls_verify' "
        echo "*****************"
    fi
fi
