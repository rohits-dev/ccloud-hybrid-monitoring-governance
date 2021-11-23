# Introduction

Demo of Health+ and Governance on Confluent Cloud
Repository contains kubernetes resources to run confluent platform along with MongoDB and MySql using GitOps approach with fluxcd 2.0
Repository also allows secrets to be encrypted using mozilla sops and flux. 


# Steps to run

## Fork the repository
Fork the repository to commit files to sync to your own cluster. Concept is repo is synced to a Kubernetes cluster for more information please read about [GitOps](https://opengitops.dev/)

## Install fluxcd cli

brew install fluxcd/tap/flux

> for more information https://fluxcd.io/docs/installation/

## Set environment variable

```bash
export GITHUB_TOKEN=<github token>
export GITHUB_USER=<github_user_name>
export GITHUB_REPO=<name_of_forked_repo>
```
Please set below environment variable with api keys for Confluent Cloud.

```bash
export CONFLUENT_CLOUD_BOOTSTRAP_SERVER_URL=<bootstrap-url-with-port>
export CONFLUENT_CLOUD_SCHEMA_REGISTRY_URL=<schema-registry-url>


export CONFLUENT_CLOUD_API_KEY=<api-key-with-permission-to-confluent-cloud>
export CONFLUENT_CLOUD_API_SECRET=<api-secret-with-permission-to-confluent-cloud>

export CONFLUENT_CLOUD_KAFKA_API_KEY=<api-key-with-permission-to-a-kafka-cluster-confluent-cloud>
export CONFLUENT_CLOUD_KAFKA_API_SECRET=<api-secret-with-permission-to-a-kafka-cluster-confluent-cloud>


export CONFLUENT_CLOUD_SCHEMA_REGISTRY_API_KEY=<api-key-with-permission-to-schema-registry-in-confluent-cloud>
export CONFLUENT_CLOUD_SCHEMA_REGISTRY_API_SECRET=<api-secret-with-permission-to-schema-registry-in-confluent-cloud>
```

## Create .txt files 

Run below commands to create the plain secret files

```bash
cat <<EOF > ./01_confluent/cloud-key.txt
api.key=${CONFLUENT_CLOUD_API_KEY}
api.secret=${CONFLUENT_CLOUD_API_SECRET}
EOF


cat <<EOF > ./01_confluent/cloud-sasl.txt
username=${CONFLUENT_CLOUD_KAFKA_API_KEY}
password=${CONFLUENT_CLOUD_KAFKA_API_SECRET}
EOF

cat <<EOF > ./01_confluent/cloud-sr.txt
username=${CONFLUENT_CLOUD_SCHEMA_REGISTRY_API_KEY}
password=${CONFLUENT_CLOUD_SCHEMA_REGISTRY_API_SECRET}
EOF

cat <<EOF > ./01_confluent/cloud-client.txt
#Required connection configs for Kafka producer, consumer, and admin
bootstrap.servers=${CONFLUENT_CLOUD_BOOTSTRAP_SERVER_URL}
security.protocol=SASL_SSL
sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule   required username='${CONFLUENT_CLOUD_KAFKA_API_KEY}'   password='${CONFLUENT_CLOUD_KAFKA_API_SECRET}';
sasl.mechanism=PLAIN
#Required for correctness in Apache Kafka clients prior to 2.6
client.dns.lookup=use_all_dns_ips

#Best practice for Kafka producer to prevent data loss
acks=all

#Required connection configs for Confluent Cloud Schema Registry
schema.registry.url=${CONFLUENT_CLOUD_SCHEMA_REGISTRY_URL}
basic.auth.credentials.source=USER_INFO
basic.auth.user.info=${CONFLUENT_CLOUD_SCHEMA_REGISTRY_API_KEY}:${CONFLUENT_CLOUD_SCHEMA_REGISTRY_API_SECRET}

client.id=gess-producer
EOF

```


## Kubernetes setup

Repository uses gpg keys encryption for secrets, with flux [SOPS Mozilla](https://fluxcd.io/docs/guides/mozilla-sops/). 

`setup.sh` will also create a few secret files using the .txt files. 

Run `./setup.sh` which would create a secret key and apply to kubernetes.

## Commit the changed files

Commit all files which are changed by `setup.sh`, these would include encrypted secrets.

## Configure flux to run with Git repo

Please update the repository name 

```bash
flux bootstrap github \
  --owner=$GITHUB_USER \
  --repository=$GITHUB_REPO \
  --branch=main \
  --path=./ \
  --personal
```

# Miscellaneous commands 

`alias k=kubectl`

## force reconcile on git / kustomization
flux reconcile source git flux-system
flux reconcile kustomization flux-system


## Reset commands

### Reset offsets



```bash
kafka-consumer-groups --command-config 01_confluent/cloud-client.txt --bootstrap-server $CONFLUENT_CLOUD_BOOTSTRAP_SERVER_URL --list

kafka-consumer-groups --command-config 01_confluent/cloud-client.txt --bootstrap-server $CONFLUENT_CLOUD_BOOTSTRAP_SERVER_URL --group connect-mongo-sink-accounts --reset-offsets --to-earliest --all-topics

kafka-consumer-groups --command-config 01_confluent/cloud-client.txt --bootstrap-server $CONFLUENT_CLOUD_BOOTSTRAP_SERVER_URL --group connect-mongo-sink-txns --reset-offsets --to-earliest --all-topics
```

### Reset connect

Stop publisher

```
k delete -f 02_atm-publisher/gess-datagen.yaml 
```

Create publisher

```
k apply -f 02_atm-publisher/gess-datagen.yaml 
```

Remove all connectors

```
k delete -f 07_connectors/mysql-source-accounts.yaml
k delete -f 07_connectors/mongo-sink-accounts.yaml
k delete -f 07_connectors/mongo-sink-txns.yaml
```

Remove connect cluster

```
k delete -f 01_confluent/connect.yaml
````
Delete connect topics

```bash
kafka-topics --command-config 01_confluent/cloud-client.txt --bootstrap-server $CONFLUENT_CLOUD_BOOTSTRAP_SERVER_URL --delete --topic confluent.connect-status

kafka-topics --command-config 01_confluent/cloud-client.txt --bootstrap-server $CONFLUENT_CLOUD_BOOTSTRAP_SERVER_URL --delete --topic confluent.connect-configs

kafka-topics --command-config 01_confluent/cloud-client.txt --bootstrap-server $CONFLUENT_CLOUD_BOOTSTRAP_SERVER_URL --delete --topic confluent.connect-offsets

```

Recreate connect

```
k apply -f 01_confluent/connect.yaml
```

Recreate connectors

```
k apply -f 07_connectors/mysql-source-accounts.yaml 
k apply -f 07_connectors/mongo-sink-accounts.yaml 
k apply -f 07_connectors/mongo-sink-txns.yaml 
```