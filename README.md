# Infrastructure Repository - GCP Online Boutique (gcp-online-boutique-infra)
## Overview

This repository is responsible for provisioning and configuring the infrastructure required to run the GCP Online Boutique microservices application on a Kubernetes cluster. It automates the setup of a Kubernetes cluster using kubeadm on AWS EC2 instances, deploys ArgoCD for continuous deployment, and configures ArgoCD to monitor the application repository (gcp-online-boutique-microservices) for any changes in Kubernetes manifests.
