# pSSID Data Analytics Pipeline
A data analytics pipeline for pSSID that receives, stores, and visualizes WiFi
test metrics gathered by Raspberry Pi WiFi probes.

<p align="center">
<img src="images/data-pipeline-selected.png" alt="data-pipeline-selected" width="45%"></img>
<img src="images/data-pipeline-architecture.png" alt="data-pipeline-architecture" width="45%"></img>
</p>

Picture on the left is an overview of the entire pSSID architecture with the
role of this data analytics pipeline highlighted. In short, it receives test results
(metrics) gathered by the probes, stores and visualizes them.

Picture on the right is the architecture of the pipeline itself. It leverages the
idea of the ELK stack, simply replacing `Elasticsearch` and `Kibana` with `Opensearch`
and `Grafana`, resepctively.

## Requirements
The setup of the pipeline assumes that you have a virtual machine running Ubuntu 22
and that the machine has Docker installed. If not, you could install it with
```
sudo apt update && sudo apt install docker.io docker-compose -y
```

## Installation
1. Clone this repository to the machine you would like to host the pipeline on. Each
service has its own `docker-compose` file for better modularization. If demand
changes, say you need more `Opensearch` nodes, you could simply provision more nodes
without touching other components of the pipeline.

2. Set passwords for `Opensearch`, which is required since version 2.12.0.
The easiest way to do so is with environment variables. Add the following lines to
your `.bashrc` file. This documentation uses `admin` as the username
and `OpensearchInit2024` as the password for demonstration.
```
export OPENSEARCH_INITIAL_ADMIN_PASSWORD=OpensearchInit2024
export OPENSEARCH_USER=admin
export OPENSEARCH_PASSWORD=OpensearchInit2024
```
:warning: These variables are consumed by `opensearch-one-node.yml` and
`logstash.yml`, so it is not recommended that you change the variable names unless
there is a good reason. You could freely change their values.

Don't forget to run
```
source ~/.bashrc
```
to load the environment variables.

:warning::warning:
Note that this approach with environment variables requires that you do not
run `docker-compose` with `sudo`, since the root user cannot read the
environment variables defined by non-root users. Make sure the current user is in
the `docker` group so that you can directly run `docker-compose` without `sudo`.
Add yourself to the `docker` group and activate it by running the following command.
```
sudo usermod -aG docker ${USER} && newgrp docker
```

:warning::warning:`Opensearch` requires `vm.max_map_count` to be at least 262144.
Check your current value by running
```
sysctl vm.max_map_count
```
and if it is too low, say 65530 by default on some machine, edit the
`/etc/sysctl.conf` file and add the following
```
vm.max_map_count=262144
```
Apply the change
```
sudo sysctl -p
```

3. Configure `Logstash`. Create a directory on the host machine,
say `logstash-pipeline`, with at least a
`logstash.conf` file in it. `logstash.conf` contains input, output sources, and
custom filters you would like to implement. A sample file is provided inside the
directory `logstash-pipeline`. You could use it as your pipeline directory and add
more `.conf` files to it.

Open `logstash.yml` and edit the following TODO item.

Mount the directory you just created to the `pipeline` directory inside the
container.
```
# TODO: mount your pipeline directory into the container. USE ABSOLUTE PATH!
- <ABS_PATH_TO_YOUR_PIPELINE_DIRECTORY>:/usr/share/logstash/pipeline
```

4. (Optional) Configure Grafana Google SSO and email alerting. 
You can optionally enable Single Sign-On (SSO) with Google and configure email alerting for Grafana alerts.  
To disable either feature, comment out the corresponding environment variables in `grafana.yml`:

| Feature        | Variables to Comment Out          |
|----------------|-----------------------------------|
| Google SSO     | `GF_AUTH_*`                       |
| Email Alerting | `GF_SMTP_*`                       |

---

---

#### Google SSO Configuration

1. **Register your application with Google**

   Follow Grafana’s official documentation to obtain a **Google Client ID** and **Client Secret**:  
   👉 [Configure Google Authentication in Grafana](https://grafana.com/docs/grafana/latest/setup-grafana/configure-security/configure-authentication/google/)

2. **Create or edit your `.env` file**

   Add the following variables:

   ```env
   GOOGLE_CLIENT_ID=your-google-client-id
   GOOGLE_CLIENT_SECRET=your-google-client-secret

#### Email Alerting through SMTP

**Follow this Grafana tutorial to configure email alerts**
Refer to the documentation <a href="https://grafana.com/docs/grafana/latest/alerting/configure-notifications/manage-contact-points/integrations/configure-email/"> here</a>. Your SMTP username and from_address will be the email that you want the alerts to be sent from. 
*Note that this email must have 2FA configured and that SMTP may be disabled if you're using a university email.* Here's <a href="https://support.google.com/mail/answer/185833?hl=en">a guide</a> for how to set up an app password to use with SMTP. Save your SMTP credentials in your .env file.

7. Start the three components of the service with
`docker-compose`.

```
docker-compose -f <path-to-opensearch.yml> up -d
docker-compose -f <path-to-logstash.yml> up -d
docker-compose -f <path-to-grafana.yml> --env-file .env up -d
```
OPTIONAL: you could also start the opensearch dashboard in the same way.
```
docker-compose -f <path-to-opensearch-dashboard.yml> up -d
```

By default, `Logstash` listens for `Filebeat` input at port 9400, `Opensearch`
listens for `Logstash` input at port 9200, `Grafana` dashboard is hosted at
port 3000, and the optional `Opensearch` dashboard is hosted at port 5601.
Make sure the firewall settings allow external traffic to ports 9400, 3000, and
5601.

## Usage
### Filebeat
Use the Ansible playbook <a href="https://github.com/UMNET-perfSONAR/ansible-playbook-filebeat">here</a> and follow the instructions to install Filebeat onto a list of probes. Ensure that the machine you clone the Ansible playbook to has SSH access to each probe on the list. The role that this playbook deploys can be found <a href="https://github.com/UMNET-perfSONAR/ansible-role-filebeat">here</a>.

If any changes need to be made to the Filebeat configuration, edit the Jinja2 template inside the role. This can be accomplished by cloning the role inside the playbook directory and directly editing templates/filebeat.yml.j2, without having to publish the role to Ansible Galaxy.

### logstash.conf
This file contains the input source, custom filters, and output destination. See the
sample file for more details. The input and output fields generally require minimal
changes, if any. Most of the customization is done in the `filter` field. You could
implement as many filters as you like, and a more complicated filtering at the
Logstash level usually results in simpler configuration later at the Grafana level.

Ruby scripts for parsing the JSON, converting the durations, and normalizing the endpoints were sourced from <a href="https://github.com/perfsonar/logstash/tree/master/perfsonar-logstash/perfsonar-logstash">here</a>.

### OpenSearch Dashboard
While running the optional OpenSearch dashboard, navigate to '<pipeline-hostname>:5601' and sign in when prompted. This documentation uses `admin` as the username and `OpensearchInit2024` as the password for demonstration. The most important functionality of the dashboard is checking the indices that Logstash is generating, as well as the JSON format of the data within each index. To use the dashboard for this purpose, navigate to 'Dev Tools' in the sidebar and type GET <index-name-here>/_search. 

### Grafana
Navigate to the `Grafana` dashboard at `<pipeline-hostname>:3000`. By default,
`Grafana` username and password are both `admin`. If you only want to view the dashboard and not edit, and you have Google SSO configured, you can also sign in with your university email. To add a data source, select
`Opensearch` in the list of available sources and configure as follows.
<img src="images/add-data-source.png" alt="add-data-source"></img>
Remarks:
* `URL`: use https instead of http, and check `Basic auth` and `Skip TLS Verify`
under the `Auth` section. `User` and `Password` under `Basic Auth Details` are
`OPENSEARCH_USER` and `OPENSEARCH_PASSWORD` defined earlier, which are `admin` and
`OpensearchInit2024` in our example. Also make sure to use the Docker aliased
hostname `opensearch-node1` instead of the actual hostname of your pipeline machine.
* `Index name`: wild card patterns are allowed here. To see the list of all
`Opensearch` indices, run
```
curl -u <OPENSEARCH_USER>:<OPENSEARCH_PASSWORD> --insecure \
    "https://localhost:9200/_cat/indices?v"
```
on the pipeline machine.
* Click on `Get Version and Save`, which should automatically populate the `Version`
and `Max concurrent Shard Requests` fields, indicating a successful configuration.

Having configured the data sources, now you could create visualization panels and
dashboards.

### Grafana Visualization
The exported-grafana-json folder contains the exported json for an example Grafana dashboard. To import this dashboard into Grafana, navigate to Dashboards -> New -> Import and drag and drop the JSON file where prompted.

### Queries on Grafana
