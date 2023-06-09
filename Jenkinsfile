pipeline {
    agent any
    environment {
        APP_NAME = "my-health"
        ACR_REPO = "myhealthcontainerregistry.azurecr.io"
        CLIENT_NAME = "${APP_NAME}" + "-client"
        SERVER_NAME = "${APP_NAME}" + "-server"
    }

    stages {

        stage("Cleanup Workspace") {
            steps {
                cleanWs()
            }
        }
    
    
        stage("Checkout from SCM") {
            steps {
                git branch: 'dev', credentialsId: 'github', url: 'https://github.com/alejandro945/my-health-ops'
            }
        }
    

    
        stage("Update the Deployment Tags") {
            steps {
                sh """
                    echo "Server"
                    cat ./k8s/pods/server-deployment.yml
                    sed -i 's/${SERVER_NAME}.*/${SERVER_NAME}:${IMAGE_TAG}/g' ./k8s/pods/server-deployment.yml
                    cat ./k8s/pods/server-deployment.yml
                    echo "Client"
                    cat ./k8s/pods/client-deployment.yaml
                    sed -i 's/${CLIENT_NAME}.*/${CLIENT_NAME}:${IMAGE_TAG}/g' ./k8s/pods/client-deployment.yaml
                    cat ./k8s/pods/client-deployment.yaml
                """
            }
        }

        stage("Push the changed deployment file to Git") {
            steps {
                sh """
                    git config --global user.name "alejandro945"
                    git config --global user.email "alejo8677@gmail.com"
                    git add .
                    git commit -m "Updated Deployment Manifest Automation"
                """
                withCredentials([gitUsernamePassword(credentialsId: 'github', gitToolName: 'Default')]) {
                    sh "git push https://github.com/alejandro945/my-health-ops dev"
                }
            }
        }

    }

}