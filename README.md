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
- **NOTE**: We are intentionally allowing the audit step to fail because this repo has too many vulnerabilities to address but we still want to know about them.

**Reminder: Setup your repo credentials for your DOCKERHUB_USERNAME and DOCKERHUB_PASSWORD**

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
        run: npm audit || echo "Failed - Vulnerabilities detected, pipeline continuing"

  build-and-push:
    name: Build and Push Docker Image
    needs:
      - lint
      - dependency-scan
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
    needs: build-and-push
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Install Trivy
        run: |
          curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/master/contrib/install.sh | sh -s -- -b /usr/local/bin
      - name: Scan Docker Image
        run: |
          trivy image ${{ secrets.DOCKERHUB_USERNAME }}/spacex-api:latest
```

---

## **Part 3: ECS Cluster and Service Setup**

### **Step 4: Create an ECS Cluster with Fargate**
- Navigate to AWS ECS.
- Create a new cluster with Infrastructure as "AWS Fargate (serverless)".
- Name the cluster (`SpaceX-Cluster`).
- \*Optionally: Enable CloudWatch Container Insights under the Monitoring section
- Tag it with `Owner` where the value is `<insert your username>`
- Click **Create**.

### **Step 5: Create a Task Definition**
- Go to **Task Definitions**.
- Create a new task definition for **Fargate**.
- Set parameters:
  - **Task Definition Family Name:** `SpaceXAPITask`
  - **Launch Type:** AWS Fargate
  - **OS, Architecture:** Linux/X86_64
  - **Network Mode:** `awsvpc`
  - **Memory and CPU:** 512 CPU (0.5vCPU) and 512MB Memory
  - **Task Role:** N/A
  - **Task Execution Role:** DefaultEcsTaskExecutionRole
- Add the API container:
  - **Container Name:** `spacex-api`
  - **Essential Container:** NO. This is because of image problems and debugging required.
  - **Image:** `docker.io/<your dockerhub username>/spacex-api:latest`
  - **Port Mappings:** Map container port 6673
  - **Environment Variables:** Add the following envvars:
      - DB_HOST=localhost
      - DB_NAME=spacex
      - DB_USERNAME=root
      - DB_PASSWORD=toor
  - **OPTIONAL: Configure Log collection to use awslogs-group of `/ecs/<your-aws-username>/spacex-api`**
      - You will need to go create this log group in CloudWatch Logs before hitting submit to create this Task Definition

- Add the DB container by clicking `Add container`:
  - **Container Name:** `spacex-db`
  - **Essential Container:** Yes
  - **Image:** `docker.io/mongo:6.0`
  - **Port Mappings:** Map container port 27017
  - **Environment Variables:** Add the following envvars:
      - MONGO_INITDB_DATABASE=spacex
      - MONGO_INITDB_ROOT_USERNAME=root
      - MONGO_INITDB_ROOT_PASSWORD=toor
  - **OPTIONAL: Configure Log collection to use awslogs-group of `/ecs/<your-aws-username>/spacex-db`**
      - You will need to go create this log group in CloudWatch Logs before hitting submit to create this Task Definition
- Save and **Register**.

### **Step 6: Create an ECS Service**
- Navigate to your ECS cluster.
- Click **Create Service**.
- Choose `Capacity provider strategy` and make sure we have a capacity provider listed for FARGATE with Base 0 and Weight 1
- **Platform version:** LATEST
- **Deployment Configuration:**
  - **Application type:** `Service`
  - **Task definition Family:** SpaceXAPITask
  - **Revision:** (LATEST), generally be sure you know which revision you choose. Default and Latest are typically not the same.
  - **Service Name:** `SpaceXAPIService`
  - **Number of Tasks:** Start with 1.
  - **Availability Zone rebalancing**: OFF
- Click **Deploy**.

### **Step 7: Configure Load Balancing and Security**
- **Create a Target Group:**
  - Target type: **IP**
  - IP Address: Get the private IP address of the running Task
  - Protocol/Port: **HTTP/6673**
  - **NOTE**: When registering the target make sure to click `Incldue as pending below` and THEN you can `Create target group`. This is easy to miss. Ensure that the availability zone happens to correspond to one of the subnets that the Load Balancer cares about.
  - Health check path: `/`
- **Associate with an ALB:**
  - Modify ALB listener rules to forward traffic from port 80 (or an unused port of some kind) to this target group.

### **Step 8: Set Security Groups**
- Ensure security groups allow traffic on the from the internet on the port you chose for your ALB.
- Test service using the ALB DNS name. NOTE: The API still has some bugs in deployment, don't be surprised if the container is down and routing to the Application Load Balancer's DNS name fails. Most important is to understand these parts.

---


## **Part 4: Add ECS Update to Pipeline**

### **Step 9: Add job to update ECS Cluster Service**
Add a job to the CI/CD pipeline to trigger an ECS service update after deploying a new image. This will force a new deployment and ***because we tagged our earlier image `latest`*** it will automatically pull the image of the same name from. The effect is that it automatically grabs the latest image we built in the earlier job.
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

**Reminder: Setup the secrets that are in this new job.**

### **Step 10: Add workflow dispatch for manual pipeline runs**
- It canbe useful to manually trigger pipeline runs so add the following to your `on` statement:
```yml
on:
  push:
    branches: [ develop ]
  workflow_dispatch:
```

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

