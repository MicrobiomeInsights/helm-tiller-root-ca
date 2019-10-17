#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


# 1 year + 10 days
DAYS=375

##
## Tiller Server
##

# DATE and USAGE is used in the x509.env file
DATE=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
USAGE="Tiller Server"

if [[ ! -r "${DIR}/x509.env" ]] ; then 
  cp -f "${DIR}/x509.env.tmpl" "${DIR}/x509.env"
  echo "Please edit '${DIR}/x509.env' and re-run this script"
  exit 1
fi

source "${DIR}/x509.env"

TILLERDIR="${DIR}/pki/tiller/${DATE}"
mkdir -p "${TILLERDIR}/private"

TILLER_KEY=$TILLERDIR/private/tls.key
TILLER_CSR=$TILLERDIR/tls.csr
TILLER_CERT=$TILLERDIR/tls.crt

# I had trouble with openssl not overwriting the CSR before and using an old one
# so remove everything first to start clean from multiple runs
# rm -rf $TILLER_KEY $TILLER_CSR $TILLER_CERT

# generate a private key
openssl genrsa -out $TILLER_KEY 4096
ret=$?
if [[ $ret != 0 ]]; then
    echo "Failed to generate RSA key"
    exit 1
fi 

chmod 600 $TILLER_KEY

# generate a CSR - use defaults from openssl.csr.cnf
openssl req -config openssl.csr.cnf -key $TILLER_KEY -new -sha256 -out $TILLER_CSR -subj "$SUBJ"
ret=$?
if [[ $ret != 0 ]]; then
    echo "Failed to generate CSR file"
    exit 1
fi 

## --- NORMALLY, the CSR is sent to the CA and the CA signs it and returns the signed CERT
## --- Here, we do the CA signing step immediately, with SAN extensions

# Need to be inside the CA directory to get access to the databases there
cd "${DIR}/pki/ca/intermediate/"

# sign the CSR with the intermediate CA, generating the signed client certificate.
openssl ca \
    -config $PWD/openssl.cnf   \
    -extensions server_cert \
    -days $DAYS \
    -notext \
    -md sha256 \
    -in $TILLER_CSR \
    -out $TILLER_CERT

ret=$?
if [[ $ret != 0 ]]; then
    echo "Failed to generate and sign the certificate"
    exit 1
fi 

echo
echo "created: "
echo "  tls.key: ${TILLER_KEY/$DIR\//./}"
echo "  tls.csr: ${TILLER_CSR/$DIR\//./}"
echo "  tls.crt: ${TILLER_CERT/$DIR\//./}"
echo 
echo " *** ALL DONE ***" 
echo "To rotate/roll the Tiller Server with this new server certificate, "
echo "run './apply-tiller-server-cert.sh $(dirname ${TILLER_CERT/$DIR\//./})'"
echo "*****************"
echo 
