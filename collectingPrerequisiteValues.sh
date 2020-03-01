#!/bin/sh


echo "Acquiring deployment values to continue the installation...."
export IDENTITIES_DEPLOYMENT_NAME=$(az deployment show -n azuredeploy-prereqs-dev --query properties.outputs.identitiesDeploymentName.value -o tsv) && \
export DELIVERY_ID_NAME=$(az group deployment show -g $RESOURCE_GROUP -n $IDENTITIES_DEPLOYMENT_NAME --query properties.outputs.deliveryIdName.value -o tsv) && \
export DELIVERY_ID_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $DELIVERY_ID_NAME --query principalId -o tsv) && \
export DRONESCHEDULER_ID_NAME=$(az group deployment show -g $RESOURCE_GROUP -n $IDENTITIES_DEPLOYMENT_NAME --query properties.outputs.droneSchedulerIdName.value -o tsv) && \
export DRONESCHEDULER_ID_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $DRONESCHEDULER_ID_NAME --query principalId -o tsv) && \
export WORKFLOW_ID_NAME=$(az group deployment show -g $RESOURCE_GROUP -n $IDENTITIES_DEPLOYMENT_NAME --query properties.outputs.workflowIdName.value -o tsv) && \
export WORKFLOW_ID_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $WORKFLOW_ID_NAME --query principalId -o tsv) && \
export GATEWAY_CONTROLLER_ID_NAME=$(az group deployment show -g $RESOURCE_GROUP -n $IDENTITIES_DEPLOYMENT_NAME --query properties.outputs.appGatewayControllerIdName.value -o tsv) && \
export GATEWAY_CONTROLLER_ID_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $GATEWAY_CONTROLLER_ID_NAME --query principalId -o tsv) && \
export RESOURCE_GROUP_ACR=$(az group deployment show -g $RESOURCE_GROUP -n $IDENTITIES_DEPLOYMENT_NAME --query properties.outputs.acrResourceGroupName.value -o tsv)

echo "${DELIVERY_ID_PRINCIPAL_ID}, ${DRONESCHEDULER_ID_PRINCIPAL_ID}, ${WORKFLOW_ID_PRINCIPAL_ID}, ${GATEWAY_CONTROLLER_ID_PRINCIPAL_ID}"

az account show -o table

# Wait for AAD propagation
echo "Waiting for AAD identity propagation...."
az ad sp show --id ${DELIVERY_ID_PRINCIPAL_ID} 
az ad sp show --id ${DRONESCHEDULER_ID_PRINCIPAL_ID} 
az ad sp show --id ${WORKFLOW_ID_PRINCIPAL_ID} 
az ad sp show --id ${GATEWAY_CONTROLLER_ID_PRINCIPAL_ID} 

# Wait for AAD propagation
#echo "Waiting for AAD identity propagation...."
#until az ad sp show --id ${DELIVERY_ID_PRINCIPAL_ID} &> /dev/null ; do echo "$?: Waiting for DELIVERY_ID_PRINCIPAL_ID #propagation" && sleep 5; done
#until az ad sp show --id ${DRONESCHEDULER_ID_PRINCIPAL_ID} &> /dev/null ; do echo "Waiting for DRONESCHEDULER_ID_PRINCIPAL_ID propagation" && sleep 5; done
#until az ad sp show --id ${WORKFLOW_ID_PRINCIPAL_ID} &> /dev/null ; do echo "Waiting for WORKFLOW_ID_PRINCIPAL_ID propagation" && sleep 5; done
#until az ad sp show --id ${GATEWAY_CONTROLLER_ID_PRINCIPAL_ID} &> /dev/null ; do echo "Waiting for GATEWAY_CONTROLLER_ID_PRINCIPAL_ID propagation" && sleep 5; done

# Export the kubernetes cluster version
export KUBERNETES_VERSION=$(az aks get-versions -l $LOCATION --query "orchestrators[?default!=null].orchestratorVersion" -o tsv)
export SERVICETAGS_LOCATION=$(az account list-locations --query "[?name=='${LOCATION}'].displayName" -o tsv | sed 's/[[:space:]]//g')

# Deploy cluster and microservices Azure services
az group deployment create -g $RESOURCE_GROUP --name azuredeploy-dev --template-file ${PROJECT_ROOT}/azuredeploy.json \
--parameters servicePrincipalClientId=${SP_APP_ID} \
            servicePrincipalClientSecret=${SP_CLIENT_SECRET} \
            servicePrincipalId=${SP_OBJECT_ID} \
            kubernetesVersion=${KUBERNETES_VERSION} \
            sshRSAPublicKey="$(cat ${SSH_PUBLIC_KEY_FILE})" \
            deliveryIdName=${DELIVERY_ID_NAME} \
            deliveryPrincipalId=${DELIVERY_ID_PRINCIPAL_ID} \
            droneSchedulerIdName=${DRONESCHEDULER_ID_NAME} \
            droneSchedulerPrincipalId=${DRONESCHEDULER_ID_PRINCIPAL_ID} \
            workflowIdName=${WORKFLOW_ID_NAME} \
            workflowPrincipalId=${WORKFLOW_ID_PRINCIPAL_ID} \
            appGatewayControllerIdName=${GATEWAY_CONTROLLER_ID_NAME} \
            appGatewayControllerPrincipalId=${GATEWAY_CONTROLLER_ID_PRINCIPAL_ID} \
            acrResourceGroupName=${RESOURCE_GROUP_ACR} \
            acrResourceGroupLocation=$LOCATION

export VNET_NAME=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.aksVNetName.value -o tsv) && \
export CLUSTER_SUBNET_NAME=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.aksClusterSubnetName.value -o tsv) && \
export CLUSTER_SUBNET_PREFIX=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.aksClusterSubnetPrefix.value -o tsv) && \
export CLUSTER_NAME=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.aksClusterName.value -o tsv) && \
export CLUSTER_SERVER=$(az aks show -n $CLUSTER_NAME -g $RESOURCE_GROUP --query fqdn -o tsv) && \
export FIREWALL_PIP_NAME=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.firewallPublicIpName.value -o tsv) && \
export ACR_NAME=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.acrName.value -o tsv) && \
export ACR_SERVER=$(az acr show -n $ACR_NAME --query loginServer -o tsv) && \
export DELIVERY_REDIS_HOSTNAME=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.deliveryRedisHostName.value -o tsv)

# Restrict cluster egress traffic
az group deployment create -g $RESOURCE_GROUP --name azuredeploy-firewall --template-file ${PROJECT_ROOT}/azuredeploy-firewall.json \
--parameters aksVnetName=${VNET_NAME} \
            aksClusterSubnetName=${CLUSTER_SUBNET_NAME} \
            aksClusterSubnetPrefix=${CLUSTER_SUBNET_PREFIX} \
            firewallPublicIpName=${FIREWALL_PIP_NAME} \
            serviceTagsLocation=${SERVICETAGS_LOCATION} \
            aksFqdns="['${CLUSTER_SERVER}']" \
            acrServers="['${ACR_SERVER}']" \
            deliveryRedisHostNames="['${DELIVERY_REDIS_HOSTNAME}']"

# Shared
export GATEWAY_SUBNET_PREFIX=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.appGatewaySubnetPrefix.value -o tsv)

#  Install kubectl
sudo az aks install-cli

# Get the Kubernetes cluster credentials
az aks get-credentials --resource-group=$RESOURCE_GROUP --name=$CLUSTER_NAME

# Create namespaces
kubectl create namespace backend-dev

# setup tiller in your cluster
kubectl apply -f $K8S/tiller-rbac.yaml
helm init --service-account tiller

#Integrate Application Insights instance


# Acquire Instrumentation Key
export AI_NAME=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.appInsightsName.value -o tsv)
export AI_IKEY=$(az resource show \
                    -g $RESOURCE_GROUP \
                    -n $AI_NAME \
                    --resource-type "Microsoft.Insights/components" \
                    --query properties.InstrumentationKey \
                    -o tsv)

# add RBAC for AppInsights
kubectl apply -f $K8S/k8s-rbac-ai.yaml


# setup AAD pod identity
kubectl create -f https://raw.githubusercontent.com/Azure/aad-pod-identity/master/deploy/infra/deployment-rbac.yaml

kubectl create -f https://raw.githubusercontent.com/Azure/kubernetes-keyvault-flexvol/master/deployment/kv-flexvol-installer.yaml

# Deploy the AppGateway ingress controller
helm repo add application-gateway-kubernetes-ingress https://appgwingress.blob.core.windows.net/ingress-azure-helm-package/
helm repo update

export GATEWAY_CONTROLLER_PRINCIPAL_RESOURCE_ID=$(az group deployment show -g $RESOURCE_GROUP -n $IDENTITIES_DEPLOYMENT_NAME --query properties.outputs.appGatewayControllerPrincipalResourceId.value -o tsv) && \
export GATEWAY_CONTROLLER_PRINCIPAL_CLIENT_ID=$(az identity show -g $RESOURCE_GROUP -n $GATEWAY_CONTROLLER_ID_NAME --query clientId -o tsv)
export APP_GATEWAY_NAME=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.appGatewayName.value -o tsv)
export APP_GATEWAY_PUBLIC_IP_FQDN=$(az group deployment show -g $RESOURCE_GROUP -n azuredeploy-dev --query properties.outputs.appGatewayPublicIpFqdn.value -o tsv)

helm install application-gateway-kubernetes-ingress/ingress-azure \
     --name ingress-azure-dev \
     --namespace ingress-controllers \
     --set appgw.name=$APP_GATEWAY_NAME \
     --set appgw.resourceGroup=$RESOURCE_GROUP \
     --set appgw.subscriptionId=$SUBSCRIPTION_ID \
     --set appgw.shared=false \
     --set kubernetes.watchNamespace=backend-dev \
     --set armAuth.type=aadPodIdentity \
     --set armAuth.identityResourceID=$GATEWAY_CONTROLLER_PRINCIPAL_RESOURCE_ID \
     --set armAuth.identityClientID=$GATEWAY_CONTROLLER_PRINCIPAL_CLIENT_ID \
     --set rbac.enabled=true \
     --set verbosityLevel=3 \
     --set aksClusterConfiguration.apiServerAddress=$CLUSTER_SERVER

# Create a self-signed certificate for TLS
export EXTERNAL_INGEST_FQDN=$APP_GATEWAY_PUBLIC_IP_FQDN
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -out ingestion-ingress-tls.crt \
    -keyout ingestion-ingress-tls.key \
    -subj "/CN=${APP_GATEWAY_PUBLIC_IP_FQDN}/O=fabrikam"

kubectl apply -f $K8S/k8s-resource-quotas-dev.yaml

## Deny all ingress and egress traffic

kubectl apply -f $K8S/k8s-deny-all-non-whitelisted-traffic-dev.yaml

