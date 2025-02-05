# Phase 1: Comprehensive Walkthrough - ECS Deployment with CI/CD

## Overview
This guide provides a complete walkthrough of deploying the SpaceX-API to AWS ECS using Fargate. It also integrates a CI/CD pipeline using GitHub Actions to automate linting, dependency scanning, Docker image building/pushing, and ECS deployment updates.

### **Objectives**
- Build and push a Docker image for the SpaceX-API
- Set up a GitHub Actions pipeline
- Deploy the application using AWS ECS with Fargate
- Configure security and networking for proper accessibility
- Automate ECS service updates via the CI/CD pipeline

---

## **Part 1: Preparing the SpaceX-API for Deployment**

### **Step 1: Clone the Repository**
```bash
git clone https://github.com/your-org/spacex-api.git
cd spacex-api
```

Ensure that the repository includes a `Dockerfile` that builds the SpaceX-API application.

### **Step 2: Build and Test the Docker Image Locally**
```bash
docker build -t spacex-api:latest .
```

Run and test the image locally:
```bash
docker run -p 8080:80 spacex-api:latest
```

Verify that the API is accessible on the appropriate port.

---

## **Part 2: CI/CD Pipeline with GitHub Actions**

### **Step 3: Set Up a GitHub Actions CI/CD Pipeline**
Create a workflow file at `.github/workflows/main.yml` in your repository.

#### **GitHub Actions Workflow:**
```yaml
name: Main - CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  lint:
    name: Lint Node.js Code
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '14'
      - name: Install Dependencies
        run: npm install
      - name: Lint Code
        run: npm run lint

  dependency-scan:
    name: Scan for Vulnerable Dependencies
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '14'
      - name: Install Dependencies
        run: npm install
      - name: Run npm Audit
        run: npm audit

  build-and-push:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Log in to DockerHub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_PASSWORD }}
      - name: Build Docker Image
        run: |
          docker build -t ${{ secrets.DOCKERHUB_USERNAME }}/spacex-api:latest .
      - name: Push Docker Image to DockerHub
        run: |
          docker push ${{ secrets.DOCKERHUB_USERNAME }}/spacex-api:latest

  container-scan:
    name: Scan Docker Image with Trivy
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Trivy
        run: |
          wget https://github.com/aquasecurity/trivy/releases/latest/download/trivy_0.40.0_Linux-64bit.deb
          sudo dpkg -i trivy_0.40.0_Linux-64bit.deb
      - name: Scan Docker Image
        run: |
          trivy image ${{ secrets.DOCKERHUB_USERNAME }}/spacex-api:latest
```

### **Step 4: Update the ECS Cluster on Deployment**
Add a job to the CI/CD pipeline to trigger an ECS service update after deploying a new image.

```yaml
  update-ecs:
    name: Update ECS Service
    runs-on: ubuntu-latest
    needs: build-and-push
    steps:
      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ${{ secrets. AWS_REGION }}
      - name: Update ECS Service
        run: |
          aws ecs update-service --cluster ${{ secrets.ECS_CLUSTER_NAME }} --service ${{ secrets.ECS_SERVICE_NAME }} --force-new-deployment
```

Replace `YourClusterName` and `YourServiceName` with the actual ECS resource names.

---

## **Part 3: ECS Cluster and Service Setup**

### **Step 5: Create an ECS Cluster with Fargate**
- Navigate to AWS ECS.
- Create a new cluster (`Networking only` for Fargate).
- Name the cluster (`FargateDemoCluster`).
- Associate it with the student VPC and the default subnet.
  - **NOTE**: Do not use ***your*** subnet, the Load Balancer and Target Group step later will run into an issue with this since we are using Fargate if you use your personal subnets.
- Click **Create**.

### **Step 6: Create a Task Definition**
- Go to **Task Definitions**.
- Create a new task definition for **Fargate**.
- Set parameters:
  - **Task Name:** `SpaceXAPITask`
  - **Task Role:** #TODO: Add Role here
  - **Network Mode:** `awsvpc`
- Add the API container:
  - **Container Name:** `SpaceXAPIContainer`
  - **Image:** `docker.io/<username>/spacex-api:latest`
  - **Memory and CPU:** 512 CPU (0.5vCPU) and 512MB Memory
  - **Port Mappings:** Map container port 6673
- Add the DB container:
  - **Container Name:** `SpaceXAPIContainer`
  - **Image:** `docker.io/<username>/spacex-api:latest`
  - **Memory and CPU:** 512 CPU (0.5vCPU) and 512MB Memory
  - **Port Mappings:** Map container port 6673
- Save and **Register**.

### **Step 7: Create an ECS Service**
- Navigate to your ECS cluster.
- Click **Create Service**.
- Choose the task definition created in Step 6.
- Configure service:
  - **Service Name:** `SpaceXAPIService`
  - **Number of Tasks:** Start with 1-2.
- Click **Deploy**.

### **Step 8: Configure Load Balancing and Security**
- **Create a Target Group:**
  - Target type: **IP**
  - Protocol/Port: **HTTP/6673**
  - Health check path: `/`
- **Associate with an ALB:**
  - Modify ALB listener rules to forward traffic from port 80 to this target group.

### **Step 9: Set Security Groups**
- Ensure security groups allow HTTP traffic.
- Test service using the ALB DNS name.

---

## **Summary**
This walkthrough covered:
- Building a Docker image for the SpaceX-API
- Setting up a GitHub Actions CI/CD pipeline for:
  - Linting and dependency scanning
  - Docker image build and push
  - Trivy container scanning
  - ECS service updates
- Deploying to ECS using Fargate
- Setting up networking, security, and a load balancer

By following these steps, students will gain hands-on experience in cloud-native application deployment with AWS ECS and CI/CD automation.

