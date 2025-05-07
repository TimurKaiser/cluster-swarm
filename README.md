# 🚀 Deploying a Docker Swarm Cluster on Google Cloud with Terraform

## 🛠️ Installation Steps

### 1. Create the Swarm Manager Node and Firewall Rules
Apply the Terraform configuration to create the **manager instance** and **firewall rules**:

```bash
terraform apply -target=google_compute_instance.manager -target=google_compute_firewall.allow-swarm
```

---

### 2. Retrieve the Swarm Worker Join Token
SSH into the manager instance, then run:

```bash
sudo docker swarm join-token -q worker
```

> **Note:** Copy the token displayed. You will need it for the worker configuration.

---

### 3. Deploy the Worker Instance Template
Apply the Terraform configuration to create the **worker instance template**:

```bash
terraform apply -target=google_compute_instance_template.worker_template
```

---

### 4. Deploy the Worker Group, Autoscaler, and Health Check
Apply the Terraform configuration to deploy the **instance group manager**, **autoscaler**, and **health check** for the workers:

```bash
terraform apply -target=google_compute_region_instance_group_manager.workers -target=google_compute_region_autoscaler.workers_autoscaler -target=google_compute_health_check.basic_health_check
```

---

### 5. Force Restart Portainer Service (Optional)
If needed, you can force a redeploy of the Portainer service on the manager node:

```bash
sudo docker service update --force portainer
```
