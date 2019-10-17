#!/bin/sh


# make the ROOT CA private key
openssl genrsa -aes256 -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

# make the root CA Certificate

openssl req -config openssl.cnf \
      -key private/ca.key.pem \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out certs/ca.cert.pem

chmod 444 certs/ca.cert.pem


