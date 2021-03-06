#!/bin/bash
BXUSER=$user BXPASS=$password BXACCOUNT=1 ./scripts/linux.sh

bx cs cluster-config $cluster
$(bx cs cluster-config $cluster | grep -v "Downloading" | grep -v "OK" | grep -v "The")
kubectl get secrets --namespace=default

kubectl delete --ignore-not-found=true svc,pvc,deployment -l app=drupal
kubectl delete --ignore-not-found=true -f local-volumes.yaml
kubectl delete --ignore-not-found=true secret mysql-pass

#Deploy drupal
echo 'password' > password.txt
tr -d '\n' <password.txt >.strippedpassword.txt && mv .strippedpassword.txt password.txt
kubectl create -f local-volumes.yaml
kubectl create secret generic mysql-pass --from-file=password.txt
kubectl create -f mysql-deployment.yaml
kubectl create -f drupal-deployment.yaml
kubectl scale deployments/drupal --replicas=2

#Check drupal is running.
export IP=$(bx cs workers $cluster | grep normal | awk '{ print $2 }')
sleep 60s #wait for the pods to be ready
HEALTH=$(curl -o /dev/null -s -w "%{http_code}\n" http://$IP:30180/install.php)
if [ $HEALTH -eq 200 ]
then
  echo "Everything looks good."
  echo "Cleaning up."
  kubectl delete --ignore-not-found=true svc,pvc,deployment -l app=drupal
  kubectl delete --ignore-not-found=true -f local-volumes.yaml
  kubectl delete --ignore-not-found=true secret mysql-pass
  echo "Deleted drupal in cluster"
else
  echo "Health check failed."
  exit 1
fi
