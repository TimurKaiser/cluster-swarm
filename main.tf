// manager and token generation
resource "google_compute_instance" "manager" {
  name         = "swarm-manager1"
  machine_type = "e2-medium"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  // docker installation and swarm init
  // portainer service creation

  // swarm token generation

  metadata_startup_script = <<-EOT
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    sudo docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')

    sudo docker service create --name portainer --publish 9000:9000 \
      --constraint 'node.role == manager' \
      --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
      --mount type=volume,src=portainer_data,dst=/data \
      portainer/portainer-ce
  EOT

  tags = ["allow-swarm", "allow-portainer", "gitlab", "test"]

}


// firewall rule to allow swarm cluster and portainer traffic
resource "google_compute_firewall" "allow-swarm" {
  name    = "allow-swarm-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["2377", "7946", "4789", "9000"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["allow-swarm", "allow-portainer", "gitlab"]
}



// template for swarm worker nodes
resource "google_compute_instance_template" "worker_template" {
  name         = "swarm-worker-template"
  machine_type = "e2-medium"

  disk {
    source_image = "ubuntu-os-cloud/ubuntu-2204-lts"
    auto_delete  = true
    boot         = true
  }

  network_interface {
    network = "default"
    access_config {
      // Ephemeral IP
    }
  }

  metadata_startup_script = <<-EOT
    # Add Docker's official GPG key:
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc

    # Add the repository to Apt sources:
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
      sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update

    docker swarm join --token ${var.worker_join_token} ${google_compute_instance.manager.network_interface.0.network_ip}:2377
  EOT

  tags = ["allow-swarm"]

}


// instance group manager for swarm worker nodes
resource "google_compute_region_instance_group_manager" "workers" {
  name               = "swarm-workers"
  region             = var.region
  base_instance_name = "swarm-worker"

  version {
    instance_template = google_compute_instance_template.worker_template.self_link
  }

  target_size = 2

  auto_healing_policies {
    health_check          = google_compute_health_check.basic_health_check.self_link
    initial_delay_sec     = 300
  }

  named_port {
    name = "http"
    port = 80
  }
  
}

// autoscaler for swarm worker nodes

resource "google_compute_region_autoscaler" "workers_autoscaler" {
  name    = "swarm-workers-autoscaler"
  region  = var.region
  target  = google_compute_region_instance_group_manager.workers.id

  autoscaling_policy {
    max_replicas    = 5
    min_replicas    = 2
    cpu_utilization {
      target = 0.6
    }
  }
  
}


// health check for swarm worker nodes

resource "google_compute_health_check" "basic_health_check" {
  name = "basic-health-check"

  tcp_health_check {
    port = 2377
  }

  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2
}
