#!/bin/bash

## Apply and/or Rotate the tiller keys ?

## Usage: 
##   apply-tiller-server-cert.sh <directory>
## 
## The argument <directory> should be a directory with a tls.key and tls.crt 
##

if [[ $# != 1 ]]; then
cat <<!EOF!
Usage: 
  apply-tiller-server-cert.sh <directory>

The argument <directory> should be a directory with a private/tls.key and tls.crt file inside. 

!EOF!
exit 0
fi 

APPLY="kubectl apply -f -"
# APPLY="cat"

DIR="$1"
KEY="$DIR/private/tls.key"
CRT="$DIR/tls.crt"

SECRET="tiller-secret"
NAMESPACE="tiller"
[[ ! -z ${NAMESPACE} ]] && NAMESPACE_OPT="-n ${NAMESPACE}"

[[ ! -r ${KEY} ]] && echo "The directory supplied does not have a private/tls.key file." && exit 1
[[ ! -r ${CRT} ]] && echo "The directory supplied does not have a tls.crt file." && exit 1

echo 
echo 
SUBJ=$(openssl x509 -in ${CRT} -text -noout | awk '/Subject: / {print $0}' )
echo $SUBJ
echo
echo

echo -n "Do you want to apply these server keys to your Tiller Server ? [y/N]: "
read ans
if [[ $ans =~ ^[yY](es)?$ ]]; then
    echo "The current kubectl context is: $(kubectl config current-context)" 
    echo -n "Use this kubernetes context? [y/N]: "
    ans="" 
    read ans
    if [[ $ans =~ ^[yY](es)?$ ]]; then
        # check if there is an existing secret
        # we only modify it, never create it. use helm init to create it
        count=$( kubectl ${NAMESPACE_OPT} get secret ${SECRET} --no-headers | wc -l ) 
        if [[ $count -ne 1 ]]; then
            echo "There is no existing ${SECRET} in ${NAMESPACE/-n /}. Please run \"helm init\" first."
            exit 2
        fi 
        #
        # modify in-place the tls.crt and tls.key values of the secret 
        #
        kubectl ${NAMESPACE_OPT} get secret ${SECRET} -o json \
        | jq --arg key "$(cat ${KEY} | base64)" \
            --arg crt "$(cat ${CRT} | base64)" \
            '.data["tls.crt"]=$crt | .data["tls.key"]=$key'  \
        | ${APPLY}

        #
        # restart the tiller service to re-read the tls secrets 
        # 
        DEPLOY="deployment/tiller-deploy"

        ## STOP Tiller
        count=0
        echo "Stopping the Tiller Pod(s)"
        while :; do 
            kubectl ${NAMESPACE_OPT} scale --current-replicas=1 --replicas=0 ${DEPLOY} && break 
            sleep 5;
            count=$(( count + 1 ))
            [[ $count -gt 10 ]] && echo "could not stop the ${DEPLOY}" && break
        done

        ## START Tiller
        count=0
        echo "Starting the Tiller Pod(s)"
        while :; do 
            kubectl ${NAMESPACE_OPT} scale --current-replicas=0 --replicas=1 ${DEPLOY} && break
            sleep 5;
            count=$(( count + 1 ))
            [[ $count -gt 10 ]] && echo "could not restart the ${DEPLOY}" && break
        done
    fi
fi
