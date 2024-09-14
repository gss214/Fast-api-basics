
# Fast API Basics with Pokemons

## Description

This project is just to learn the basics of FastAPI by creating an API themed around Pokémon. It's a fun way to get started with FastAPI, and now it's also been enhanced with a CI/CD pipeline using Tekton and Kind for automated builds and deployments.

## Setup Development Environment with Devbox

For a streamlined development environment, consider using [Devbox](https://www.jetify.com/devbox). Devbox provides a powerful, isolated development environment with tools and dependencies ready to go.

### Installation

Follow the installation guide on [Devbox's official website](https://www.jetify.com/devbox) to set up Devbox on your machine. This will help you manage your development environment efficiently, especially when working with multiple dependencies or projects.

Once Devbox is set up, you can quickly configure your environment by running:

```bash
devbox shell
```

This will ensure that all necessary tools and dependencies are available for development.

## Run

To run the project install the required libraries listed in `requirements.txt`:

```bash
pip install -r requirements.txt
```

Then, start the application with the following command:

```bash
python3 -m uvicorn app.main:app --reload
```

## Endpoints

To explore the application endpoints, visit the `/docs` page after starting the server. This page provides an interactive interface for testing the API.

## CI/CD Pipeline with Tekton and Kind

### Overview

This project includes a CI/CD pipeline set up using Tekton and Kind to automate the build and deployment of the FastAPI application. The entire CI/CD flow is contained in the `cicd.sh` script, which automates each step of the pipeline from setting up the cluster to deploying the application.

### CI/CD Flow:

1. **Setup Kind Cluster:**
   - The script starts by setting up a Kubernetes cluster locally using Kind (Kubernetes IN Docker). This allows for easy local testing and development without the need for cloud resources.
   - The cluster is configured using a YAML file (`simple-cluster.yaml`) which defines the nodes and networking for the cluster.

2. **Install Tekton Pipelines and Dashboard:**
   - Tekton Pipelines is installed to manage CI/CD tasks and pipelines within the Kubernetes cluster. Tekton Dashboard is also installed to provide a UI for monitoring the pipeline runs and their statuses.

   - You can monitor the PipelineRun by accessing the Tekton Dashboard. To do this, start by running the following command to set up a proxy: `kubectl proxy`. Then, access the Tekton Dashboard at: `http://localhost:8001/api/v1/namespaces/tekton-pipelines/services/tekton-dashboard:http/proxy`
   This will open the Tekton Dashboard where you can see detailed views of your PipelineRuns, including logs and execution statuses. Refer to the image below for an example of what the Tekton Dashboard looks like:

   ![alt text](/imgs/tekton-dash.png)

3. **Build Docker Image:**
   - A Tekton Task is configured to build the Docker image of the FastAPI application using Docker-in-Docker (DinD). This task encapsulates the build process within the CI/CD pipeline, ensuring consistency across builds.

4. **Load Docker Image into Kind:**
   - After the image is built, the script uses `kind load docker-image` to load the image into the Kind cluster, making it accessible for the application deployment.

5. **Deploy the Application:**
   - The FastAPI application is deployed to the cluster using a Kubernetes Deployment YAML file. This deployment defines the number of replicas, the container image to use, and other deployment configurations.
   - A Service is also created to expose the FastAPI application, making it accessible externally for testing and use.

6. **PipelineRun Automation:**
   - The `cicd.sh` script automates the entire process by executing the Tekton Pipeline, which handles building the image and deploying the application seamlessly.
   - In a production setup, the pipeline would also push the Docker image to a container registry (like Docker Hub or a private registry) and manage deployments using those images.

After deploying the application, you can access it by using the kubectl port-forward command to redirect traffic from the pod's port to your local machine. Run the following command:

```bash
kubectl port-forward <pod-name> 5000:5000
```

Replace `<pod-name>` with the name of the pod where application is running. This will forward port 5000 from the pod to port 5000 on your local machine, allowing you to access the application at http://localhost:5000.

### Challenges and Local Adjustments

- The pipeline was designed to work entirely locally for development purposes, using Kind and Tekton to simulate a production-like CI/CD environment.
- In a production environment, the pipeline would push the Docker image to a container registry and manage deployments directly from there.
