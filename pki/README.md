# An AdHoc Certificate Authority for Helm / Tiller 
### Brian Onn (brian.a.onn@gmail.com)

This directory contains a ROOT CA and an Intermediate CA signed by the Root CA 

This is for use by Helm / Tiller.  It can easily be adapted for other uses

Setup as here : 
https://jamielinux.com/docs/openssl-certificate-authority/index.html

The CA is vaild for 20 years.  The Intermediate CA is valid for 10 years. 

The server and client certificates signed by the Intermediate CA should only be valid for 2 years max. 

You can invalidate every certificate signed by the Intermediate CA by revoking the Intermediate CA.
This is not something you would normally do. Instead, revoke the individual signed certificates. 

Only revoke the Intermediate CA if it has been compromised. 

If the Root CA is compromised, all of the signed Intermediate CA's created from it (if there is more than one)
should be revoked, then the ROOT CA should be re-created. 

## Revoking certificates
```
certfile=newcerts/1006.pem
openssl ca -revoke $certfile -crl_reason "superseded"
```
crl_reason can be: (https://tools.ietf.org/html/rfc5280#section-6.3.2)
 *  unspecified
 *  keyCompromise
 *  cACompromise
 *  affiliationChanged
 *  superseded
 *  cessationOfOperation
 *  certificateHold
 *  removeFromCRL
 *  privilegeWithdrawn
 *  aACompromise


## Generating Helm Client certificates 

run:
```
make-helm-client-cert.sh
```
Output:
```
$ ./make-helm-client-cert.sh 
Generating RSA private key, 4096 bit long modulus
.................................................................................................................................................................................................++
...........................................................................................++
e is 65537 (0x10001)
Using configuration from openssl.cnf
Enter pass phrase for ./private/intermediate.key.pem:
```
Enter your private key passphrase for the Intermediate CA (saved above when you created the CA certificate )
```
Check that the request matches the signature
Signature ok
Certificate Details:
        Serial Number: 4108 (0x100c)
        Validity
            Not Before: Oct  2 09:22:33 2019 GMT
            Not After : Oct 11 09:22:33 2020 GMT
        Subject:
            countryName               = CA
            stateOrProvinceName       = British Columbia
            organizationName          = Hyperion Technology, Inc.
            organizationalUnitName    = DevOps
            commonName                = Hyperion Technology Inc Helm Client 20191002T092016Z
        X509v3 extensions:
            X509v3 Basic Constraints: 
                CA:FALSE
            Netscape Cert Type: 
                SSL Client, S/MIME
            Netscape Comment: 
                OpenSSL Generated Client Certificate
            X509v3 Subject Key Identifier: 
                D1:30:74:CD:94:26:C0:B4:63:EC:68:28:11:31:D3:91:C3:A0:51:AB
            X509v3 Authority Key Identifier: 
                keyid:A6:05:6C:55:18:FA:5C:7E:46:A8:DB:63:52:44:D3:D8:CB:28:DB:2A

            X509v3 Key Usage: critical
                Digital Signature, Non Repudiation, Key Encipherment
            X509v3 Extended Key Usage: 
                TLS Web Client Authentication, E-mail Protection
Certificate is to be certified until Oct 11 09:22:33 2020 GMT (375 days)
Sign the certificate? [y/n]:
```
Review the above and if it all looks good, then answer **Yes** here to actually sign the certificate with your Intermediate CA certificate. 
```
1 out of 1 certificate requests certified, commit? [y/n]
```
Answer **Yes** again, to commit the signature data to the CA's database.  This is used for revocations later. 
```
Write out database with 1 new entries
Data Base Updated
created:
  tls.key: ./pki/helm/2019-10-02T09:20:16Z/private/tls.key
  tls.csr: ./pki/helm/2019-10-02T09:20:16Z/tls.csr
  tls.crt: ./pki/helm/2019-10-02T09:20:16Z/tls.crt
```

The output contains the locations of the private key `tls.key` and the public certificate `tls.crt`.  Note the directory `./pki/helm/2019-10-02T09:20:16Z` here as this will be used to rotate new server keys into the Tiller server, using a script that resets the kubernetes secret and restarts the Tiller deployment. 

## Rotating In New Tiller Server TLS certificates
After you have made new certificates, you will want to rotate these into a running Tiller Server. To do this, run the script `apply-tiller-server-cert` and supply it with the directory name containing the server certificates as the first argument, i.e.

```
$ ./apply-tiller-server-cert ./pki/helm/2019-10-02T09:20:16Z
```

The output will be:
```
Subject: C=CA, ST=British Columbia, O=Hyperion Technology, Inc., OU=DevOps, CN=Hyperion Technology Inc Helm Client 20191002T092016Z

Do you want to apply these server keys to your Tiller Server ? [y/N]: 
```

If you are presented with the correct Subj and CommonName (CN) above, then answer **Yes** to apply the new certificate to the Tiller Server, otherwise answer **No**.
```
The current kubectl context is: do-sfo2-k8s-rocket-staging-hyperionex-io
Use this kubernetes context? [y/N]: 
```
The current kubernetes context is displayed, so you can verify that you will be updating the secrets into the correct cluster. 

**THIS IS IMPORTANT TO NOTE IF YOU RUN MULTIPLE CLUSTERS**

Anser **Yes** if you are satisfied that the context setting is correct.  Otherwise, chose **No** here and reset your cluster with `kubectl config use-context` and start again. 

```
Warning: kubectl apply should be used on resource created by either kubectl create --save-config or kubectl apply
secret/tiller-secret configured
Stopping the Tiller Pod(s)
deployment.extensions/tiller-deploy scaled
Starting the Tiller Pod(s)
deployment.extensions/tiller-deploy scaled
```

Congratulations! At this point, the kubernetes secret with the TLS certificate for the Tiller Server is updated and the server was successfully restarted. 

Test the server connection with `helm --tiller-namespace tiller ls --tls`

Verify that the newest TLS certificate is installed with: 
```
kubectl -n tiller get secrets tiller-secret -o json \
  | jq '.data["tls.crt"]' \
  | tr -d '"' \
  | python -m base64 -d \
  | openssl x509 -text -noout  \
  | grep Subject:
```

The output should match the **Subject** line from certificate just created: 
```
Subject: C=CA, ST=British Columbia, O=Hyperion Technology, Inc., OU=DevOps, CN=Hyperion Technology Inc Helm Client 20191002T092016Z
```

## The directory structure : 

```txt
pki/
├── make-helm-client-cert.sh            # shell script to make the helm client certificate
├── make-tiller-server-cert.sh          # shell script to make the tiller server certificate
├── openssl.csr.cnf                     # openssl config used by above scripts to make CSR
└── README.txt                          # this README

pki/ca/
├── certs
│   └── ca.cert.pem                     # Root CA certificate
├── crl                                 # Root CA Certificate Revocation List (database)
├── index.txt                           # Root CA list of certificates issued by this CA (database)
├── index.txt.attr                      # Root CA settings for certification issues
├── index.txt.old                       # database backup
├── intermediate                            # Intermediate CA directory
│   ├── certs   
│   │   ├── ca-chain.cert.pem               # Root CA and Intermediate CA chain
│   │   └── intermediate.cert.pem           # Intermediate CA certificate
│   ├── crl                                 # Intermediate CA Certificate Revocation List (database)
│   ├── crlnumber                           # Intermediate CA CRL Number (database)
│   ├── csr
│   │   └── intermediate.csr.pem            # Intermediate CA Certificate Signing Request (CSR)
│   ├── index.txt                           # Intermediate CA list of certificates issued by this CA (database)
│   ├── index.txt.attr                      # Intermediate CA settings for certificate issues
│   ├── index.txt.attr.old                  # database backup
│   ├── index.txt.old                       # settings backup 
│   ├── newcerts                            # every certificate signed by the Intermediate CA (needed for revoke)
│   │   ├── 1000.pem
│   │   ├── 1001.pem
│   │   ├── 1002.pem
│   │   ├── 1003.pem
│   │   ├── 1004.pem
│   │   ├── 1005.pem
│   │   ├── 1006.pem
│   │   └── 1007.pem
│   ├── openssl.cnf                         # Intermediate CA openssl config file
│   ├── private
│   │   └── intermediate.key.pem            # Intermediate CA Private Key for CA certificate 
│   ├── serial                              # Intermediate CA serial number (database)
│   └── serial.old                          # Intermediate CA serial number backup (database)
├── newcerts                            # every certificate signed by the Root CA (needed for revoke)
│   └── 1000.pem
├── openssl.cnf                         # Root CA openssl config file
├── private
│   └── ca.key.pem                      # Root CA Private Key for CA certificate
├── serial                              # Root CA serial number (database)
└── serial.old                          # Root CA serial number (database)

pki/helm/
├── helm.cert.pem                       # Helm Client Public Certificate
├── helm.csr.pem                        # Helm Client Certificate Signing Request
└── private
    └── helm.key.pem                    # Helm Client Private Key for the Certificate

pki/tiller/
├── tiller.cert.pem                     # Tiller Server Public Certificate
├── tiller.csr.pem                      # Tiller Server Certificate Signing Request
└── private
    └── tiller.key.pem                  # Tiller Server Private Key for the Certificate
```
