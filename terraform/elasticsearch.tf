
resource "aws_security_group" "elasticsearch" {
  count       = var.enable_external_elasticsearch ? 1 : 0
  name        = "elasticsearch-kibana-sg"
  description = "Access for Elasticsearch and Kibana"
  vpc_id      = module.vpc.vpc_id

  # This optional host is intentionally disabled by default. Restrict every
  # public listener to the operator's current public IPv4 CIDR.
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.elasticsearch_allowed_cidr]
  }

  # Kibana UI - restricted to the configured operator IP.
  ingress {
    description = "Kibana UI"
    from_port   = 5601
    to_port     = 5601
    protocol    = "tcp"
    cidr_blocks = [var.elasticsearch_allowed_cidr]
  }

  # Elasticsearch API - restricted to the configured operator IP.
  ingress {
    description = "Elasticsearch API"
    from_port   = 9200
    to_port     = 9200
    protocol    = "tcp"
    cidr_blocks = [var.elasticsearch_allowed_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "elasticsearch-kibana-sg"
    Environment = "dev"
    Project     = "eks-terraform-lab"
  }
}


data "aws_ssm_parameter" "ubuntu_ami" {
  name = "/aws/service/canonical/ubuntu/server/noble/stable/current/amd64/hvm/ebs-gp3/ami-id"
}


resource "aws_instance" "elasticsearch" {
  count                       = var.enable_external_elasticsearch ? 1 : 0
  ami                         = data.aws_ssm_parameter.ubuntu_ami.value
  instance_type               = "m7i-flex.large"
  subnet_id                   = module.vpc.public_subnets[0]
  vpc_security_group_ids      = [aws_security_group.elasticsearch[0].id]
  associate_public_ip_address = true
  key_name                    = var.elasticsearch_key_name

  lifecycle {
    precondition {
      condition     = !var.enable_external_elasticsearch || var.elasticsearch_key_name != null
      error_message = "Set elasticsearch_key_name to an existing EC2 key pair when enabling the optional host."
    }
  }

  user_data = <<-EOF
    #!/bin/bash
    set -euxo pipefail

    export DEBIAN_FRONTEND=noninteractive

    apt-get update
    apt-get install -y curl gnupg

    curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch \
      | gpg --dearmor --yes \
          -o /usr/share/keyrings/elasticsearch-keyring.gpg

    echo "deb [signed-by=/usr/share/keyrings/elasticsearch-keyring.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" \
      > /etc/apt/sources.list.d/elastic-9.x.list

    apt-get update
    apt-get install -y elasticsearch kibana

    # Configure Elasticsearch as a single-node cluster

    # Configure Elasticsearch for single-node operation
    sudo sed -i '/^[[:space:]]*cluster\.initial_master_nodes:/d' /etc/elasticsearch/elasticsearch.yml

    # Remove duplicate http.host entries
    sudo sed -i '/^[[:space:]]*http\.host:/d' /etc/elasticsearch/elasticsearch.yml

    # Disable Elasticsearch authentication and HTTP TLS for lab use
    sed -i '/^[[:space:]]*xpack\.security\.enabled:/d' \
        /etc/elasticsearch/elasticsearch.yml

    # Remove the existing HTTP SSL configuration block
    sed -i '/^[[:space:]]*xpack\.security\.http\.ssl:/,/^[[:space:]]*[^[:space:]#]/{
    /^[[:space:]]*xpack\.security\.http\.ssl:/d
    /^[[:space:]]*enabled:/d
    /^[[:space:]]*keystore\.path:/d
    /^[[:space:]]*truststore\.path:/d
    }' /etc/elasticsearch/elasticsearch.yml

    cat >> /etc/elasticsearch/elasticsearch.yml <<'ESCONFIG'

    cluster.name: devops-lab
    node.name: es-node-1
    discovery.type: single-node
    http.host: 0.0.0.0
    xpack.security.enabled: false
    xpack.security.http.ssl.enabled: false
    ESCONFIG

    sudo sed -i '/^[[:space:]]*keystore\.path: certs\/http\.p12$/d' \
        /etc/elasticsearch/elasticsearch.yml

    # Enable Elasticsearch
    systemctl daemon-reload
    systemctl enable elasticsearch
    systemctl start elasticsearch

    # Configure Kibana to listen on the network interface
    # sed -i 's/^#server.host: "localhost"/server.host: "0.0.0.0"/' \
    #   /etc/kibana/kibana.yml

    sudo sed -i '/^[[:space:]]*#\?server\.host:/d' /etc/kibana/kibana.yml
    echo 'server.host: "0.0.0.0"' | \
        sudo tee -a /etc/kibana/kibana.yml

    systemctl enable kibana
    systemctl restart kibana
  EOF

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  tags = {
    Name        = "devops-lab-elasticsearch"
    Environment = "dev"
    Project     = "eks-terraform-lab"
  }
}
