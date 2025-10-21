# fzi-demo

## Pre-req.
- AWS CLI connected with a secret configured (aws configure)
- You can install K9S (optional or play with terraform to change replica count)

## Deployment

### Deploy infra first
- Be sure 3b_eks.tf is named 3b_eks.tf.o (not deployed)
- terraform apply
- Connect edge to transit + add to network domain (put edge into control_plane domain)
- Enable DCF
- Once deployed, rename 3b_eks.tf.o 3b_eks.tf
- terraform apply

### Once second part is deployed

- Reconfigure kubectl
```bash
aws eks update-kubeconfig --region eu-central-1 --name eks-fra-runtimeA
```
- Identify private LB IP

```bash
terraform output nginx_runtimeA_external_ip
```

Update the below with the output of first.
```bash
aws ec2 describe-network-interfaces --filters "Name=description,Values=*MyIdFromFirstCommand*" --query 'NetworkInterfaces[].{SubnetId:SubnetId,PrivateIpAddress:PrivateIpAddress,AvailabilityZone:AvailabilityZone}' --output table
```

### Enable K8S Policy list feature

```bash
#! /usr/bin/env bash

set -o nounset
set -o errexit
set -o pipefail

ACTION=${1:-}
DATA=${2:-}
CONTROLLER=${CONTROLLER:-}
USERNAME=${USERNAME:-admin}
PASSWORD=${PASSWORD:-}

CURL=${CURL:-curl}
JQ=${JQ:-jq}

API="https://${CONTROLLER}/v2/api"
API25="https://${CONTROLLER}/v2.5/"

CREDENTIALS=$(mktemp)

curl -vvv --fail --insecure --no-progress-meter "${API}" \
  -o "${CREDENTIALS}" \
  -d "action=login" \
  -d "username=${USERNAME}" \
  -d "password=${PASSWORD}"

CID=$(jq -r .CID <"${CREDENTIALS}")
curl -v -k ${API} \
  -H 'content-type: application/json' \
  -H 'accept: application/json' \
  -H "Authorization: cid ${CID}" \
  -d "{\"action\":\"enable_controller_feature\",\"feature\":\"k8s_dcf_policies\",\"CID\":\"$CID\"}"
```

Example

| AvailabilityZone | PrivateIpAddress | SubnetId |
|---|---|---|
| eu-central-1b | 10.2.1.36 | subnet-08c48296859da2921 |
| eu-central-1a | 10.2.0.47 | subnet-03467ca6a00a1734c |

## Destroy deployment

```bash
terraform destroy
```
After the error because edge is still connected to transit:
- disconnect it from transit,
- remove edge from control-plane network domain,
- re run terraform destroy -refresh=false

## Test list

- Using K9S, get shell access to a pod and try to curl http://monip.org and check egress IP.
  - should be Aviatrix spoke gateway as we use distributed egress.