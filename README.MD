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

2. Save your terraform outputs [Our Infrastructure creation last aprox 5 minutes]

![Resources](./assets/az-resources.png)

To see acr sensitive password on your terminal run the following command:

```sh
terraform output -no-color acr_password
```

**Note:** Delete our infrastructure using terraform with the following command:

```sh
terraform destroy -auto-approve
```

## Configuration Management

### CouchDB and pipeline slave Ansible Playbook

1. Install Ansible in your local machine

```sh
sudo apt update
apt-get install ansible
```

2. Change the IP address in the inventory/hosts file with the public IP address of the VM created in the previous step.

```sh
[azure_vm]
azure_vm-host ansible_host=host@X.X.X.X
```

3. Run our playbook with the following command:

```sh
cd ansible && ansible-playbook -i hosts.yml playbook.yml --extra-vars "@secrets.yml" -e "ansible_ssh_pass={{ansible_password}}" --ssh-extra-args='-o StrictHostKeyChecking=no'
```
![Ansible](./assets/ansible.png)

Wait for 1 minutes [User Binding] and then run the following playbook:

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
kubectl config get-contexts
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
4. Change our database endpoint, pvc node affinity of jenkins and public jetstack ip address in the following files: (https://www.base64encode.org/)

```sh
#./k8s/secrets/server-sc.yaml
http://admin:password@X.X.X.X:5984/ 
# already base encoded echo "http://admin:password@X.X.X.X:5984/" | base64
# aHR0cDovL2FkbWluOnBhc3N3b3JkQDIwLjEyNy41Mi4xMjg6NTk4NC8=
# ./k8s/services/jenkins-svc.yaml
loadBalancerIP: X.X.X.X # K8S Default public ip address (aks public ip)
# dev /Jenkinsfile
# http://52.149.201.78/ in cd trigger
```

**Optional** Enable ingress addon in our cluster for expose our runners apps [sonar and jenkins] and create ingress yaml

```sh
az aks enable-addons --addons http_application_routing --name my-health-aks --resource-group my-health-rg
az aks disable-addons --addons http_application_routing --name my-health-aks --resource-group my-health-rg --no-wait
``` 

5. Configure ACR integration for existing AKS clusters. The az aks update --attach-acr command uses the permissions of the user running the command to create the ACR role assignment. This role is assigned to the kubelet managed identity [3 minutes]

```sh
az aks update -n my-health-aks -g my-health-rg --attach-acr myHealthContainerRegistry
```

6. Run our bash script with the following command:

```sh
cd k8s && chmod 777 deploy.sh && ./deploy.sh
```
![k8s](./assets/k8s.png)

7. See nginx ingress public ip address or client service public ip address

```sh
kubectl get svc -n client
# Optional
kubectl get svc -n kube-system
```

8. Unlock jenkins server

- Get jenkins public ip address

```sh
kubectl get svc -n runners
```

- Go to jenkins public ip address and unlock jenkins with the following command:

```sh
kubectl exec -it -n runners $(kubectl get pods -n runners | grep jenkins | awk '{print $1}') -- cat /var/jenkins_home/secrets/initialAdminPassword
#admin - 847b07c1a71d494eab2de1d4a4e1479a
```

- Install default plugins continue as admin and save and finish

### CI / CD Pipeline configuration

#### Sonarqube configuration

- Go to sonarqube public ip address and login with admin and admin credentials

- Create token in administration -> security -> users -> admin -> generate token

- Change admin permissions to user in administration -> security -> users -> admin -> permissions -> apply all

#### Jenkins configuration

- Configure node runner in manage jenkins -> manage nodes and clouds -> new node and add node with the following configuration: docker-agent as name, vm ip address, remote root directory /home/healthadmin/jenkins, permanent agent, launch method: launch agent via ssh, node_credentials: add credentials with username and password, host key verification strategy: non verifying verification strategy

- Gor to admin -> Dashboard -> Configure and Click on Add new Token, write a name 'jenkins_api_token' for it and then press Generate. We need to store this Token in a safe place because there is no way to recover it in the future unless creating a new one.

- Go to admin -> Credentials -> System -> Global credentials -> Add credentials and add:

    1. Sonarqube server with sonar_credentials as id and secret text for sonar server token.
    2. Username and password for github.
    3. Username with password for acr_credentials. 
    4. Secret text for jenkins_api_token for trigger cd pipeline as jenkins_api_token.

![auth](./assets/token.png)

- Install sonarqube scanner in manage jenkins -> manage plugins -> available and install without restart.

- Go to manage jenkins -> Global tool configuration and add sonarqube scanner with **sonar** as name

- Go to manage jenkins -> Configure system -> sonarqube servers and check env variables nad add sonarqube server with sonar as name and http://sonar-svc.runners.svc.cluster.local:9000 as server url and auth token as sonar-credentials

- Configure your CI pipeline, go create a job, select pipeline and enter dev-pipeline as name. Then select GitHub project with the following url: https://github.com/alejandro945/my-health-dev, GitHub hook trigger for GITScm polling and Pipeline script from SCM main branch.

- Configure your CD pipeline, go create a job, select pipeline and enter ops-pipeline as name. Then select discard old builds with max of 2, select this project is parameterized-string parameter and IMAGE_TAG as name, select trigger builds remotely with **gitops-token** as string, finally Pipeline script from SCM **dev** branch with the following url:https://github.com/alejandro945/my-health-ops.

![pipe](./assets/pipeline.png)

#### Github configuration

1. To create our GitHub Webhook, we need to open our repository and click on settings. Then click on Webhooks and Add webhook

2. Inside the Payload URL text box, we need to write the direction to our Jenkins Server ip, plus: /github-webhook/. The payload must have both / to work, otherwise it'll throw some error. Inside the Secret box, we'll paste the Jenkins API Token from section bellow.

Check your pipeline creating a commit in your repository. [Build at the first time manually] 💥

#### ArgoCD configuration

1. Get initial password

```sh
kubectl -n runners get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

2. Vinculate repository

3. Create Project with my-health as name

4. Enable auto sync

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
```
![prometheus](./assets/prometheus.png)

### ArgoCD

```sh
kubectl port-forward --address 0.0.0.0 service/argocd-server --namespace runners 32000:443
# admin - kubectl -n runners get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
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
# admin - admin
# admin - password
```
![sonar](./assets/sonarqube.png)