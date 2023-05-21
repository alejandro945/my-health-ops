## K8s Resources Creation
kubectl apply -f ./namespaces/
kubectl apply -f ./configMaps/
kubectl apply -f ./clusterRoles/
kubectl apply -f ./volumes/
kubectl apply -f ./secrets/
kubectl apply -f ./pods/
kubectl apply -f ./hpa/
kubectl apply -f ./services/
kubectl apply -f ./ingress/
kubectl apply -n runners -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argo-app.yaml
# Ingress to runners and metrics pods
# kubectl port-forward --address 0.0.0.0 service/grafana-service --namespace metrics 30000:80
# kubectl port-forward --address 0.0.0.0 service/prometheus-service --namespace metrics 31000:8080
# kubectl port-forward --address 0.0.0.0 service/argocd-server --namespace runners 32000:443
# kubectl port-forward --address 0.0.0.0 service/jenkins-service --namespace runners 33000:8080
# kubectl port-forward --address 0.0.0.0 service/sonar-svc --namespace runners 34000:9000