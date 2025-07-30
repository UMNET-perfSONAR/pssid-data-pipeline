# pSSID Data Analytics Pipeline

A data analytics pipeline for pSSID that receives, stores, and visualizes WiFi test metrics gathered by Raspberry Pi WiFi probes.

<p align="center">
<img src="images/data-pipeline-selected.png" alt="data-pipeline-selected" width="45%"></img>
<img src="images/data-pipeline-architecture.png" alt="data-pipeline-architecture" width="45%"></img>
</p>

**Left image:** Overview of the entire pSSID architecture with the data analytics pipeline highlighted. The pipeline receives test results (metrics) from probes, stores them, and provides visualization.

**Right image:** Architecture of the pipeline itself, leveraging the ELK stack concept with `Opensearch` replacing `Elasticsearch` and `Grafana` replacing `Kibana`.

## 📋 Requirements

- Ubuntu 22 virtual machine
- Docker and Docker Compose installed

### Installing Docker (if needed)
```bash
sudo apt update && sudo apt install docker.io docker-compose -y
```

## 🚀 Installation

### Step 1: Clone the Repository
Clone this repository to your host machine. Each service has its own `docker-compose` file for better modularization, so when you scale, you could simply provision more nodes
without touching other components of the pipeline. 

### Step 2: Configure OpenSearch Security
OpenSearch requires passwords since version 2.12.0. Set up environment variables by adding these lines to your `.bashrc` file (this documentation uses `admin` as the username and `OpensearchInit2024` as the password for demonstration),
`nano ~/.bashrc`
```bash
export OPENSEARCH_HOST=https://opensearch-node1:9200
export OPENSEARCH_INITIAL_ADMIN_PASSWORD=OpensearchInit2024
export OPENSEARCH_USER=admin
export OPENSEARCH_PASSWORD=OpensearchInit2024
```

> ⚠️ **Note:** These variable names are used by `opensearch-one-node.yml` and `logstash.yml`. You can freely change their values, but do not edit names unless for a good reason.

Then reload the environment variables:
```bash
source ~/.bashrc
```

### Step 3: Configure Docker Permissions
Add your user to the docker group to avoid using `sudo` (since the root user cannot read the environment variables defined by non-root users):
```bash
sudo usermod -aG docker ${USER} && newgrp docker
```

> ⚠️ **Important:** Running with `sudo` prevents access to user environment variables.

### Step 4: Set System Requirements
OpenSearch requires `vm.max_map_count` of at least 262144.

Check current value:
```bash
sysctl vm.max_map_count
```

If it's too low, edit `/etc/sysctl.conf` and add:
```
vm.max_map_count=262144
```

Apply changes:
```bash
sudo sysctl -p
```

### Step 5: Configure Logstash
1. Create a `logstash-pipeline` directory with a `logstash.conf` file
2. Use the provided sample configuration in the `logstash-pipeline` directory as a starting point
3. Edit `logstash.yml` to mount your pipeline directory:

```yaml
# TODO: mount your pipeline directory into the container. USE ABSOLUTE PATH!
- <ABS_PATH_TO_YOUR_PIPELINE_DIRECTORY>:/usr/share/logstash/pipeline
```

### Step 6: (Optional) Configure Grafana Authentication and Alerting
> 💡 **Tip:** To disable SSO or email alerting, comment out variables starting with `GF_AUTH_` or `GF_SMTP_` in `grafana.yml`

#### Google SSO Setup
1. **Register with Google:** Follow [Grafana's Google Authentication guide](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/google/)
2. **Create `.env` file** with:
   ```env
   GOOGLE_CLIENT_ID=your-google-client-id
   GOOGLE_CLIENT_SECRET=your-google-client-secret
   ```

#### Email Alerting (SMTP)
1. Configure following [Grafana's email alert documentation](https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-email/)
2. For Gmail, see [Google's app password guide](https://support.google.com/mail/answer/185833?hl=en)
3. Add SMTP credentials to `.env` file

### Step 7: (Optional) Configure Grafana HTTPs using nginx and Certbot
> 💡 **Tip:** To disable Grafana HTTPs, remove the nginx and certbot sections under `services` in grafana.yml, and remove `nginx-html` and `certbot-etc` under volumes.

```bash
docker-compose -f grafana.yml run --rm --entrypoint="" certbot \
  certbot certonly --webroot -w /var/www/certbot \
           -d <PIPELINE-HOSTNAME> \
           --email YOUR-UNIQNAME@umich.edu --agree-tos --no-eff-email
```

If you're getting the error `Certbot failed to authenticate some domains (authenticator: webroot)`, use `docker ps` to check that your nginx container is running without errors.

After successfully running the command above, delete the grafana.conf file and rename grafana-https.conf to grafana.conf.

Then run:
```bash
docker exec pssid-data-pipeline_nginx_1 wget -O /etc/letsencrypt/options-ssl-nginx.conf https://raw.githubusercontent.com/certbot/certbot/master/certbot-nginx/certbot_nginx/_internal/tls_configs/options-ssl-nginx.conf
docker exec pssid-data-pipeline_nginx_1 wget -O /etc/letsencrypt/ssl-dhparams.pem https://raw.githubusercontent.com/certbot/certbot/master/certbot/certbot/ssl-dhparams.pem
```

Test the nginx config:
```bash
docker exec pssid-data-pipeline_nginx_1 nginx -t
```
If you see `nginx: configuration file /etc/nginx/nginx.conf test is successful`, then run:
```bash
docker exec pssid-data-pipeline_nginx_1 nginx -s reload
```

Use curl to test HTTPS access:
```bash
curl -I https://<PIPELINE-HOSTNAME>
```

### Step 8: Start the Services
```bash
docker-compose -f <path-to-opensearch.yml> up -d
docker-compose -f <path-to-logstash.yml> up -d
```
If you aren't already running grafana.yml from HTTPs setup above:
``bash
docker-compose -f <path-to-grafana.yml> --env-file .env up -d
```

(Optional) Start OpenSearch Dashboard:
```bash
docker-compose -f <path-to-opensearch-dashboard.yml> up -d
```

> 💡 **For debugging:** To check Logstash output, run this command after starting the logstash service:
```bash
docker logs -f logstash
```

> 💡 **Common Error:** When recreating the Grafana container, you might occasionally see `KeyError: 'Container Config'`. To resolve this issue, use `docker ps` and then run `docker rm -f <container-id>` for each container in the list. After starting Grafana, rerun all the commands above to start the services again.

## 🔌 Default Ports

| Service | Port | Purpose |
|---------|------|---------|
| Logstash | 9400 | Filebeat input |
| OpenSearch | 9200 | Logstash input |
| Grafana | 3000 | Web dashboard |
| OpenSearch Dashboard | 5601 | Web dashboard (optional) |

> 🔥 **Firewall:** Ensure ports 9400, 3000, and 5601 are open for external traffic.

## 📖 Usage Guide

### Filebeat Configuration
Use the [Ansible playbook](https://github.com/UMNET-perfSONAR/ansible-playbook-filebeat) to install Filebeat on probes. Ensure SSH access from your Ansible control node to all target probes in inventory/hosts.ini

For configuration changes:
1. Clone the [Ansible role](https://github.com/UMNET-perfSONAR/ansible-role-filebeat) into the playbook directory
2. Edit `templates/filebeat.yml.j2` directly

### Logstash Configuration (`logstash.conf`)
Contains input sources, custom filters, and output destinations. Most customization happens in the `filter` section.

Ruby parsing scripts sourced from [perfSONAR logstash repository](https://github.com/perfsonar/logstash/tree/master/perfsonar-logstash/perfsonar-logstash).

### OpenSearch Dashboard
Access at `<pipeline-hostname>:5601`
- Default credentials: `admin` / `OpensearchInit2024` (as defined in env variables above)
- Use Dev Tools to inspect indices and output: `GET <index-name>/_search`

### Grafana Setup

#### Access Dashboard
If HTTPs configured: Navigate to `https://<pipeline-hostname>/`
If HTTPS not configured: Navigate to `<pipeline-hostname>:3000`
- Default credentials: `admin` / `admin`
- Google SSO available for view-only access (if configured)

#### Add OpenSearch Data Source
1. Select OpenSearch from available sources
2. Configure as shown:

<img src="images/add-data-source.png" alt="add-data-source"></img>

**Configuration details:**
- **URL:** Use `https://opensearch-node1:9200` (Docker hostname)
- **Auth:** Enable `Basic auth` and `Skip TLS Verify`
- **Credentials:** Use your OpenSearch username/password
- **Index:** Use wildcards (e.g., `pssid-*`)

To list available indices:
```bash
curl -u <OPENSEARCH_USER>:<OPENSEARCH_PASSWORD> --insecure \
    "https://localhost:9200/_cat/indices?v"
```

#### Import Dashboard
1. Navigate to **Dashboards → New → Import**
2. Drag and drop JSON file from `exported-grafana-json` folder

## 📊 Creating Visualizations
After configuring data sources, you can create custom visualization panels and dashboards using Grafana's query builder with your OpenSearch indices.
