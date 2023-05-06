# Infrastructure Provisioning
cd terraform && terraform init && terraform apply -auto-approve
cd ../
# Database Configuration Management
cd ansible && ansible-playbook -i inventory/hosts playbook.yml
cd ../
# Kubernetes Configuration Management
az aks get-credentials --resource-group $1 --name $2 --file ./kubeconfig
kubectl config use-context $2
## K8s Resources Creation
kubectl apply -f ./k8s/namespaces/
kubectl apply -f ./k8s/configMaps/
kubectl apply -f ./k8s/clusterRoles/
kubectl apply -f ./k8s/volumes/
kubectl apply -f ./k8s/secrets/
kubectl apply -f ./k8s/pods/
kubectl apply -f ./k8s/hpa/
kubectl apply -f ./k8s/services/
kubectl apply -f ./k8s/ingress/
kubectl apply -n runners -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# Ingress to runners and metrics pods
# kubectl port-forward --address 0.0.0.0 service/grafana-service --namespace metrics 30000:80
# kubectl port-forward --address 0.0.0.0 service/prometheus-service --namespace metrics 31000:8080
# kubectl port-forward --address 0.0.0.0 service/argocd-server --namespace runners 32000:443
# kubectl port-forward --address 0.0.0.0 service/jenkins-service --namespace runners 33000:8080
# kubectl port-forward --address 0.0.0.0 service/sonar-svc --namespace runners 34000:9000