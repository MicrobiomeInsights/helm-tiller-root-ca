#!/bin/sh


# make the ROOT CA private key
openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

# make the root CA Certificate - 20 years
#
openssl req -config openssl.cnf \
      -key private/ca.key.pem \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out certs/ca.cert.pem

chmod 444 certs/ca.cert.pem


##
## Make the Intermediate CA
##

openssl genrsa -aes256 \
      -out intermediate/private/intermediate.key.pem 4096

chmod 400 intermediate/private/intermediate.key.pem

# intermediate CSR
# openssl req -config intermediate/openssl.cnf -new -sha256 \
      -key intermediate/private/intermediate.key.pem \
      -out intermediate/csr/intermediate.csr.pem

# Sign the intermediate CA certificate with the root CA - 10 years
openssl ca -config openssl.cnf -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in intermediate/csr/intermediate.csr.pem \
      -out intermediate/certs/intermediate.cert.pem


# Verify - look for OK
openssl verify -CAfile certs/ca.cert.pem \
      intermediate/certs/intermediate.cert.pem


## 
## Create the CA chain file
##

cat intermediate/certs/intermediate.cert.pem \
      certs/ca.cert.pem > intermediate/certs/ca-chain.cert.pem
chmod 444 intermediate/certs/ca-chain.cert.pem

## at this point the additional client and server 
## certificates can be created, signed by the intermediate CA
##
## See make-helm-client-cert.sh and make-tiller-server-cert.sh
