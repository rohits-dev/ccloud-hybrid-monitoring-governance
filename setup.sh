#!/bin/bash

export KEY_NAME="hybrid-confluent-cloud-demo"
export KEY_COMMENT="flux secrets"

echo 'generating secret key'
gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Comment: ${KEY_COMMENT}
Name-Real: ${KEY_NAME}
EOF


export KEY_FP=$(gpg --fingerprint "${KEY_NAME}" | sed "2q;d" | sed  "s/ //g") 

echo 'generated secret key'

echo 'exporting secret key to kubernetes secret yaml'

gpg --export-secret-keys --armor "${KEY_FP}" |
kubectl create secret generic sops-gpg \
--namespace=flux-system \
--from-file=sops.asc=/dev/stdin \
--dry-run=client \
-o yaml > sops-private-key-secret.yaml

kubectl create namespace flux-system
kubectl apply -f sops-private-key-secret.yaml


echo 'exported secret key to kubernetes secret yaml'

echo 'exporting public key for git repo'
gpg --export --armor "${KEY_FP}" > ./.sops.pub.asc
echo 'exported public key for git repo'

echo 'configure repo for encryption'

cat <<EOF > ./.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(data|stringData)$
    pgp: ${KEY_FP}
EOF

echo 'creating secret files'
kubectl -n confluent create secret generic cloud-plain \
--from-file=plain.txt=01_confluent/cloud-sasl.txt \
--dry-run=client \
-o yaml > 01_confluent/cloud-plain.yaml
sops --encrypt --in-place 01_confluent/cloud-plain.yaml

kubectl -n mongodb create secret generic mongodb-user-password \
--from-literal=password=admin \
--dry-run=client \
-o yaml > 01_mongodb/mongodb-user-password.yaml

sops --encrypt --in-place 01_mongodb/mongodb-user-password.yaml

kubectl -n flux-system create secret generic cloud-key \
--from-file=telemetry.txt=01_confluent/cloud-key.txt \
--dry-run=client \
-o yaml > 01_confluent/cloud-key.yaml

sops --encrypt --in-place 01_confluent/cloud-key.yaml

kubectl -n confluent create secret generic cloud-sr \
--from-file=basic.txt=01_confluent/cloud-sr.txt \
--dry-run=client \
-o yaml > 01_confluent/cloud-sr.yaml

sops --encrypt --in-place 01_confluent/cloud-sr.yaml

kubectl -n confluent create secret generic cloud-client \
--from-file=client.config=01_confluent/cloud-client.txt \
--dry-run=client \
-o yaml > 01_confluent/cloud-client.yaml

sops --encrypt --in-place 01_confluent/cloud-client.yaml

echo 'created secret files'

echo 'deleting secret key'

gpg --batch --fingerprint --yes --delete-secret-key $KEY_FP <<EOF 
$KEY_FP
EOF

gpg --batch --fingerprint --yes --delete-key $KEY_FP <<EOF 
$KEY_FP
EOF

echo 'deleted secret key'