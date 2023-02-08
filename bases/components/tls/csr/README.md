### Create CSR with alt_names

It is possible to create a single cert that works with many hostnames. With this approach the same cert can be used for all resources in all environments. See the files in this directory for examples.

To generate a CSR with alt_names, copy/edit or create a .conf file with all the names to be used with that cert and supply the file name to the `-config` parameter to openssl have it read the alt_names, e.g.

```
openssl req -new -out your_domain.csr -newkey rsa:2048 -nodes -sha256 -keyout your_domain.key -config your_domain.conf
```

Submit the CSR to web operations team.

# Deploying the certificate

Once the certificate has been generated, download the "as Certificate (w/ issuer after), PEM encoded" version of the cert from InCommon. The convention used in this repo is to copy the key (created during the generation of the CSR above) to <site name>/key and the certificate to <site name>/cert and add the pairs to the kustomization file in the bases/components/tls directory. Kustomize will generate the yaml required to create the TLS secrets which are used in the `Ingress` rules. See the ingress.yaml files in this project for examples of setting up TLS host rules.

# Cert and key storage

Certs and keys should not be stored in a Git repository. Although the files will live on the local drive inside the repo, they are excluded via .gitignore. See the top-level README for more details on management of these artifacts.
