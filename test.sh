#!/bin/bash

EXTERNAL_INGEST_FQDN=$1

echo "POSTing the https://$EXTERNAL_INGEST_FQDN/api/deliveryrequests....."
curl -X POST "https://$EXTERNAL_INGEST_FQDN/api/deliveryrequests" --header 'Content-Type: application/json' --header 'Accept: application/json' -k -d '{
   "confirmationRequired": "None",
   "deadline": "",
   "deliveryId": "mydelivery",
   "dropOffLocation": "drop off",
   "expedited": true,
   "ownerId": "myowner",
   "packageInfo": {
     "packageId": "mypackage",
     "size": "Small",
     "tag": "mytag",
     "weight": 10
   },
   "pickupLocation": "my pickup",
   "pickupTime": "2019-05-08T20:00:00.000Z"
 }' > deliveryrequest.json

DELIVERY_ID=$(cat deliveryrequest.json | jq -r .deliveryId)
#echo "$DELIVERY_ID"
echo 
echo
sleep 5
echo "==================== now testing whether the $DELIVERY_ID exists....."
echo 
echo  "Checking the request status via https://$EXTERNAL_INGEST_FQDN/api/deliveries/$DELIVERY_ID"

curl "https://$EXTERNAL_INGEST_FQDN/api/deliveries/$DELIVERY_ID" --header 'Accept: application/json' -k | jq '.'