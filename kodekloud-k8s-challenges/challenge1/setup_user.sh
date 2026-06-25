kubectl config set-credentials martin \
 --client-certificate=/root/martin.crt \
 --client-key=/root/martin.key

kubectl config set-context developer \
  --user=martin \
  --namespace=development

kubectl config use-context developer
