# My health Operations 🚀
This repository contains the infrastructure as code for the My Health application. Also it has configuration files for the CI/CD pipeline.
## Infrastructure Provisioning

- What will we build?

    ![Infra](./assets/infra.png)

- About our ingress controller:

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
cd ansible && ansible-playbook -i hosts.yml playbook.yml --extra-vars "@secrets.yml" -e "ansible_ssh_pass={{ansible_password}}" --ssh-extra-args='-o StrictHostKeyChecking=no'
```
![Ansible](./assets/ansible.png)

Wait for 5 minutes [User Binding] and then run the following playbook:

```sh
ansible-playbook -i hosts.yml db.yml --extra-vars "@secrets.yml" -e "ansible_ssh_pass={{ansible_password}}" --ssh-extra-args='-o StrictHostKeyChecking=no'
```

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
4. Change our database endpoint, pvc node affinity of jenkins and public jetstack ip address in the following files:

```sh
#./k8s/secrets/server-sc.yaml
http://admin:password@X.X.X.X:5984/ # already base encoded aHR0cDovL2FkbWluOnBhc3N3b3JkQDIwLjEyNy41Mi4xMjg6NTk4NC8=
#./k8s/volumes/jenkins-pvc.yaml
values:
    - aks-default-39522763-vmss000000 # Aks node name
# ./k8s/services/jenkins-svc.yaml
loadBalancerIP: X.X.X.X # K8S Default public ip address
```

5. Enable ingress addon in our cluster for expose our frontend application [**Optional** in client sefrvice change the type to load balancer]

```sh
az aks enable-addons --addons http_application_routing --name my-health-aks --resource-group my-health-rg
``` 

6. Run our bash script with the following command:

```sh
cd k8s && chmod 777 deploy.sh && ./deploy.sh
```
![k8s](./assets/k8s.png)

7. See nginx ingress public ip address

```sh
kubectl get svc -n kube-system
```


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