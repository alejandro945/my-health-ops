pipeline {
    agent any
    environment {
        APP_NAME = "my-health"
    }

    stages {
        stage("Cleanup Workspace") {
            steps {
                cleanWs()
            }
        }
    
    
        stage("Checkout from SCM") {
            steps {
                git branch: 'main', credentialsId: 'github', url: 'https://github.com/alejandro945/my-health-ops'
            }
        }
    

    
        stage("Update the Deployment Tags") {
            steps {
                sh """
                    echo "Server"
                    cat ./k8s/pod/server-deployment.yaml
                    sed -i 's/${APP_NAME}.*/${APP_NAME}:${IMAGE_TAG}/g' ./k8s/pod/server-deployment.yaml
                    cat ./k8s/pod/server-deployment.yaml
                    echo "Client"
                    cat ./k8s/pod/client-deployment.yaml
                    sed -i 's/${APP_NAME}.*/${APP_NAME}:${IMAGE_TAG}/g' ./k8s/pod/client-deployment.yaml
                    cat ./k8s/pod/client-deployment.yaml
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