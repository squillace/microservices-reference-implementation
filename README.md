# Microsoft Patterns & Practices -- Microservices Reference Implementation CNAB bundle

This bundle installs and removes the basic infrastructure portion of the Microsoft Patterns & Practices Microservices Reference Implementation located at https://github.com/mspnp/microservices-reference-implementation. (Full documentation for this implementation can be read at https://docs.microsoft.com/azure/architecture/microservices/.) This bundle installs the basic infrastructure to host the applications, but does not install the applications. NOTE: You may need more than Contributor scope on your Service Principal, but it depends upon your specific tenant and subscription permissions. The source for this bundle is located at https://github.com/squillace/microservices-reference-implementation.

To install the bundle, you MAY need elevated permissions assigned to the service principal that you pass to the installation process -- whether this is true depends on your own permissions already present in your Azure Active Directory tenant.

To create **`Owner`** permissions, perform:

```bash
export SP_DETAILS=$(az ad sp create-for-rbac --role="Owner" -o json) && \
export SP_APP_ID=$(echo $SP_DETAILS | jq ".appId" -r) && \
export SP_CLIENT_SECRET=$(echo $SP_DETAILS | jq ".password" -r) && \
export SP_OBJECT_ID=$(az ad sp show --id $SP_APP_ID -o tsv --query objectId)
```

# Contents

This repository contains a fork of https://github.com/mspnp/microservices-reference-implementation, with a porter.yaml file and associated scripts that are invoked. Use `porter explain --tag squillace/mspnp-infra:v0.2.13` to see the complete information about the bundle, and what values are needed for credentials.

## How to use

1. Install https://porter.sh
2. `porter explain --tag squillace/mspnp-infra:v0.2.13`
3. Have the credential values you need ready to use, and then `porter creds generate mspnp --tag squillace/mspnp-infra:v0.2.13`.
4. `porter install --tag squillace/mspnp-infra:v0.2.13 -c mspnp` -- assuming that you used "mspnp" in the command from step 3.
5. When done, `porter invoke --action mspnp.install-app -c mspnp microservices-reference-infra-basic` will build and install the application in this environment.
6. When that is done, capture the FQDN output from the screen, and type `porter invoke --action mspnp.test-app -c mspnp microservices-reference-infra-basic --param TEST_FQDN=<your FQDN value>`

`porter uninstall -c mspnp microservices-reference-infra-basic` will remove the entire application and infrastructure.



