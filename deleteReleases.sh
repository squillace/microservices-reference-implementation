#!/bin/bash


az login --service-principal --username $SP_APP_ID --password $SP_CLIENT_SECRET --tenant $TENANT_ID >> /dev/null

echo "Logging in and setting the proper subscription..."
az account set --subscription $SUBSCRIPTION_ID
echo "getting credentials from AKS for the cluster...."

export CLUSTER_NAME=$(az aks list --query "[].name" -g mspnp-ref-impl -o tsv)

az aks get-credentials --resource-group=$RESOURCE_GROUP --name=$CLUSTER_NAME
echo "Installing helm client...."
helm init --service-account tiller --client-only
echo "listing releases...."

helm list --output json | jq -r '.Releases[] | select(.Namespace=="backend-dev").Name' | xargs -I {} helm delete --purge {}