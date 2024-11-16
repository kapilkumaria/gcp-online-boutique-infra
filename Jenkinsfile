pipeline {
    # agent any
    agent { label 'dev' }

    environment {
        AWS_ACCESS_KEY_ID = credentials('AWS_ACCESS_KEY_ID') // Replace with your Jenkins credentials ID
        AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY') // Replace with your Jenkins credentials ID
        AWS_DEFAULT_REGION = credentials('AWS_DEFAULT_REGION') // Replace with the desired AWS region
        REPO_URL = 'https://github.com/kapilkumaria/gcp-online-boutique-infra.git'
        BRANCH_NAME = 'feature/infra-automation'
        ANSIBLE_PLAYBOOK = 'ansible/site.yaml'  // Update this with your playbook path
    }

    stages {
        stage('Clone Repository') {
            steps {
                echo 'Cloning Git Repository...'
                git branch: "${BRANCH_NAME}", url: "${REPO_URL}"
            }
        }

        stage('Check AWS CLI Version') {
            steps {
                sh 'aws --version'
            }
        }

        stage('Terraform Init') {
            steps {
                echo 'Navigating to Terraform directory and initializing...'
                dir('terraform/aws/instances') {
                    sh 'pwd'
                    echo 'Initializing Terraform...'
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Plan') {
            steps {
                echo 'Navigating to Terraform directory and running plan...'
                dir('terraform/aws/instances') {
                    echo 'Running Terraform Plan...'
                    sh 'terraform plan -lock=false'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                echo 'Navigating to Terraform directory and applying plan...'
                dir('terraform/aws/instances') {
                    echo 'Applying Terraform Plan...'
                    sh 'terraform apply -lock=false -auto-approve'
                }
            }
        }

        stage('Run Ansible Playbook') {
            steps {
                echo 'Running Ansible Playbook...'
                sh """
                ansible-playbook -i ansible/inventory/aws_ec2.yaml ${ANSIBLE_PLAYBOOK} -vvv
                """
            }
        }
        
        stage('Deploy Metric Server and Sample Nginx Application on K8s Cluster') {
            steps {
                echo 'Deploying Nginx Application...'
                sh """
                kubectl apply -f manifests/metric-server.yaml
                kubectl apply -f manifests/nginx-deployment.yaml
                """
            }
        }

        stage('Deploy Microservices Application') {
            steps {
                echo 'Cloning microservices repository...'
                checkout([
                    $class: 'GitSCM',
                    branches: [[name: '*/feature/cicd']],
                    doGenerateSubmoduleConfigurations: false,
                    extensions: [],
                    userRemoteConfigs: [[url: 'https://github.com/kapilkumaria/gcp-online-boutique-microservices.git']]
                ])
                echo 'Deploying microservices application to Kubernetes...'
                dir('kubernetes-manifests') {
                    sh 'kubectl apply -f .'
                }
            }
        }        
    }

    post {
        success {
            echo 'Pipeline completed successfully.'
        }
        failure {
            echo 'Pipeline failed. Please check logs.'
        }
    }
}
