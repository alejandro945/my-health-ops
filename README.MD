# My health Operations 🚀
This repository contains the infrastructure as code for the My Health application. Also it has configuration files for the CI/CD pipeline.
## Infrastructure Provisioning

What we will build?

![Infra](./assets/infra.png)

About our ingress controller:

![ingress](./assets/ingress-diagram.png)

1. Build our infrastructure using terraform with the following command:

```sh
cd terraform && terraform init && terraform apply -auto-approve
```

2. Save your terraform outputs [Our Infrastructure creatio last aprox 10 minutes]

![Resources](./assets/az-resources.png)

**Note:** Delete our infrastructure using terraform with the following command:

```sh
terraform destroy -auto-approve
```

## Configuration Management

### CouchDB Ansibel Playbook

1. Install Ansible in your local machine

```sh
sudo apt update
apt-get install ansible
```

2. Change the IP address in the inventory/hosts file

```sh
[azure_vm]
azure_vm-host ansible_host=host@X.X.X.X
```

3. Run our playbook with the following command:

```sh
cd ansible && ansible-playbook -i hosts.yml playbook.yml --extra-vars "@secrets.yml" -e "ansible_ssh_pass={{ansible_password}}"
```
![Ansible](./assets/ansible.png)


### Kubernetes bash script

1. Go to your kubeconfig file in your local machine

```sh
cd ~/.kube
```

**Note: For delete an specific context in your kubeconfig file**

```sh
kubectl config delete-context $1
```

2. Azure kubeconfig file configuration where $1 is the resource group name and $2 is the cluster name.

```sh
az aks get-credentials --resource-group my-health-rg --name my-health-aks --file ./config
# Merged "my-health-aks" as current context in ./config
```

3. Get the k8s context and then change the kubeconfig file

```sh
kubectl config get-contexts
kubectl config use-context $1
```
4. Change our database endpoint and pvc node affinity of jenkins

```sh
#./k8s/secrets/server-sc.yaml
http://admin:password@X.X.X.X:5984/ # already base encoded
#./k8s/volumes/jenkins-pvc.yaml
values:
    - aks-default-39522763-vmss000000 # Aks node name
```

<!-- 5. Enable ingress addon in our cluster

```sh
az aks enable-addons --addons http_application_routing --name my-health-aks --resource-group my-health-rg
``` -->

6. Run our bash script with the following command:

```sh
cd k8s && chmod 777 deploy.sh && ./deploy.sh
```
![k8s](./assets/k8s.png)


## Evidence of the application running on cloud

### CouchDB

![db](./assets/db.png)

### Client

![client](./assets/client.png)

### Server

```sh
kubectl port-forward --address 0.0.0.0 service/server-svc --namespace server 20000:80
```
![server](./assets/server.png)

### Grafana

```sh
kubectl port-forward --address 0.0.0.0 service/grafana-service --namespace metrics 30000:80
# admin - admin
```
![grafana](./assets/grafana.png)

### Prometheus

```sh
kubectl port-forward --address 0.0.0.0 service/prometheus-service --namespace metrics 31000:8080
````
![prometheus](./assets/prometheus.png)
```

### ArgoCD

```sh
kubectl port-forward --address 0.0.0.0 service/argocd-server --namespace runners 32000:443
# admin - admin
``` 
![argocd](./assets/argocd.png)

### Jenkins

```sh
kubectl port-forward --address 0.0.0.0 service/jenkins-service --namespace runners 33000:8080
```
![jenkins](./assets/jenkins.png)

### SonarQube

```sh
kubectl port-forward --address 0.0.0.0 service/sonar-svc --namespace runners 34000:9000
# admin - password
```
![sonar](./assets/sonarqube.png)