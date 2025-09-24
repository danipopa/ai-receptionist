# FreeSWITCH Kubernetes Deployment

This project provides a complete setup for deploying FreeSWITCH on Kubernetes. It includes Docker configurations, Kubernetes manifests, and scripts for building and deploying the application.

## Project Structure

- **docker/**: Contains Docker-related files.
  - **Dockerfile**: Instructions to build the Docker image for FreeSWITCH.
  - **entrypoint.sh**: Script executed when the Docker container starts.
  - **healthcheck.sh**: Script to check the health of the FreeSWITCH service.

- **k8s/**: Contains Kubernetes manifests.
  - **namespace.yaml**: Defines a Kubernetes namespace for organizing the FreeSWITCH deployment.
  - **configmap.yaml**: Creates a ConfigMap to store FreeSWITCH configuration data.
  - **deployment.yaml**: Defines the Kubernetes Deployment for FreeSWITCH.
  - **service.yaml**: Defines a Kubernetes Service to expose the FreeSWITCH deployment.
  - **persistentvolume.yaml**: Defines a PersistentVolume for FreeSWITCH storage.
  - **persistentvolumeclaim.yaml**: Creates a PersistentVolumeClaim to request storage.

- **config/**: Contains FreeSWITCH configuration files.
  - **freeswitch/**: Directory for FreeSWITCH configuration files.
    - **sofia.conf.xml**: SIP profile configuration.
    - **dialplan/**: Contains dialplan files.
      - **ai_receptionist.xml**: Dialplan for the AI receptionist functionality.
    - **autoload_configs/**: Contains autoload configuration files.
      - **event_socket.conf.xml**: Configuration for the Event Socket module.
      - **switch.conf.xml**: Core configuration settings.
    - **modules.conf.xml**: Specifies the modules to be loaded by FreeSWITCH.
  - **docker-registry.yaml**: Configuration for the Docker registry.

- **scripts/**: Contains scripts for building and deploying.
  - **build.sh**: Automates the process of building the Docker image.
  - **deploy.sh**: Automates the deployment to the Kubernetes cluster.
  - **cleanup.sh**: Cleans up resources in the Kubernetes cluster.

- **docker-compose.yml**: Defines services, networks, and volumes for the application using Docker Compose.

- **Makefile**: Contains directives for building, deploying, and cleaning up the project.

## Getting Started

1. **Clone the Repository**: 
   ```bash
   git clone <repository-url>
   cd freeswitch-k8s-deployment
   ```

2. **Build the Docker Image**:
   ```bash
   cd docker
   ./build.sh
   ```

3. **Deploy to Kubernetes**:
   ```bash
   cd k8s
   kubectl apply -f namespace.yaml
   kubectl apply -f configmap.yaml
   kubectl apply -f persistentvolume.yaml
   kubectl apply -f persistentvolumeclaim.yaml
   kubectl apply -f deployment.yaml
   kubectl apply -f service.yaml
   ```

4. **Access FreeSWITCH**: Use the service IP or domain to access the FreeSWITCH application.

## Scripts

- **build.sh**: Builds the Docker image for FreeSWITCH.
- **deploy.sh**: Deploys the application to the Kubernetes cluster.
- **cleanup.sh**: Cleans up the Kubernetes resources.

## Notes

- Ensure that your Kubernetes cluster is up and running.
- Modify configuration files as needed to suit your environment.
- For more detailed instructions, refer to the individual script files and Kubernetes manifests.