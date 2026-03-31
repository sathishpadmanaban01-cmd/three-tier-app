# Installation and execution guide

## 1) Windows laptop setup

### Install on Windows
1. Install **WSL2** and Ubuntu.
2. Install **Docker Desktop** and enable WSL integration.
3. Install **Git for Windows**.
4. Open Ubuntu in WSL and run:

```bash
cd ~/projects
# copy this repo there first
bash scripts/install-wsl-tools.sh
```

You will then have `aws`, `kubectl`, `helm`, `terraform`, and `argocd` in WSL.

## 2) AWS account prerequisites

Create or confirm:
- an IAM identity with permission to create VPC, EKS, EC2, IAM, ECR, S3, and CloudFront resources
- AWS CLI configured in WSL:

```bash
aws configure
aws sts get-caller-identity
```

## 3) Local development run

```bash
docker compose up --build
```

Open:
- frontend: http://localhost:8080
- backend swagger: http://localhost:8000/docs
- health: http://localhost:8000/health
- metrics: http://localhost:8000/metrics

## 4) Provision EKS with Terraform

Edit `infra/environments/dev/terraform.tfvars.example`, copy it to `terraform.tfvars`, then run:

```bash
cp infra/environments/dev/terraform.tfvars.example infra/environments/dev/terraform.tfvars
bash scripts/bootstrap-eks.sh
```

## 5) Install platform tools into EKS

```bash
bash scripts/install-platform.sh
```

This installs:
- Argo CD
- Prometheus + Grafana
- OpenTelemetry Collector
- Redis
- Strimzi operator
- Elasticsearch
- Kibana

Create a sample Kafka cluster after Strimzi is up:

```bash
kubectl apply -n messaging -f - <<'YAML'
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka
spec:
  kafka:
    version: 4.1.0
    replicas: 1
    listeners:
      - name: plain
        port: 9092
        type: internal
        tls: false
    config:
      offsets.topic.replication.factor: 1
      transaction.state.log.replication.factor: 1
      transaction.state.log.min.isr: 1
      default.replication.factor: 1
      min.insync.replicas: 1
    storage:
      type: ephemeral
  kraft:
    enabled: true
  entityOperator:
    topicOperator: {}
    userOperator: {}
YAML

kubectl apply -n messaging -f - <<'YAML'
apiVersion: kafka.strimzi.io/v1beta2
kind: KafkaTopic
metadata:
  name: order.created
  labels:
    strimzi.io/cluster: kafka
spec:
  partitions: 1
  replicas: 1
YAML
```

## 6) Build and push images manually first

Get your AWS account id:

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=eu-west-2
```

Login to ECR:

```bash
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
```

Build and push:

```bash
docker build -t $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/three-tier-backend:dev app/backend
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/three-tier-backend:dev

docker build -t $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/three-tier-frontend:dev app/frontend
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/three-tier-frontend:dev

docker build -t $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/three-tier-worker:dev app/worker
docker push $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/three-tier-worker:dev
```

## 7) Update GitOps values

Edit:
- `gitops/apps/backend/values.yaml`
- `gitops/apps/frontend/values.yaml`
- `gitops/apps/worker/values.yaml`

Replace `REPLACE_ME` with your ECR image URLs and MongoDB Atlas URI.

## 8) Bootstrap Argo CD app-of-apps

Update repo URL in:
- `gitops/bootstrap/argocd/app-of-apps.yaml`
- `gitops/apps/apps/*.yaml`

Then apply:

```bash
kubectl apply -f gitops/bootstrap/argocd/app-of-apps.yaml
```

Get Argo CD admin password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d && echo
```

Port-forward Argo CD:

```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
```

Open: https://localhost:8081

## 9) Access observability tools

Port-forward:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
kubectl port-forward svc/elasticsearch-master -n logging 9200:9200
kubectl port-forward svc/kibana-kibana -n logging 5601:5601
```

## 10) End of day destroy

```bash
bash scripts/destroy-all.sh
```

## Notes
- Keep MongoDB Atlas outside daily destroy if you want test data to survive.
- Elasticsearch and Kafka are intentionally single replica for lab use only.
- This repo uses a local Docker Compose stack for faster app development before EKS.
