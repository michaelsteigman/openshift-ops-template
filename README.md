## OpenShift Ops Template

### Overview

This repo includes the files, called manifests, required to manage three OpenShift environments - dev, stage and prod.  

* Dev - settings appropriate to a development environment, e.g. DEBUG is on. Additionally, this environment is where the images used across all environments are built.
    * Dev URL
    * https://console-openshift-console.apps.dev-shared-aro-e2.partners.org/k8s/cluster/projects/project-label-dev
* Stage - settings closely resemble those used in production with a notable exception of email suppression.
    * Stage URL
    * https://console-openshift-console.apps.stage-shared-aro-e2.partners.org/k8s/cluster/projects/project-label-stage
* Prod
    * Prod URL
    * https://console-openshift-console.apps.prod-shared-aro-e2.partners.org/k8s/cluster/projects/project-label-prod


Access to these projects is granted to MGB users by virtue of membership in the PAS group <your-PAS-group> you provide when the project is created. You can send an email to [Aaron Huang](mailto:ahuang8@partners.org) to request a new project.

The setup utilizes Red Hat's source-to-image (s2i) Docker build functionality as well as the OpenShift-specific ImageStream and ImageStreamTag types. It also uses OpenShift's ability to sync ImageStreamTags across clusters to provide a simple image promotion process (dev -> stage -> prod).

### Software Requirements

The files in this repo are designed to be "built" by Kustomize, a tool that is part of the Kubernetes client. There are other ways of managing 

Kustomize and the OpenShift command line client (CLI), a wrapper around Kubernetes' `kubectl`, are a required to use the resources in this repo. On a Mac, you can accomplish this with [Homebrew](https://brew.sh/):

        brew install openshift-cli kustomize

If you using Windows or Linux, see the installation instructions for [the OpenShift CLI](https://developers.redhat.com/openshift/command-line-tools) and [Kustomize](https://kubectl.docs.kubernetes.io/installation/kustomize/).

### Layout

The repo is laid out based on [guidelines](https://github.com/gnunn-gitops/standards/blob/master/folders.md) suggested by Red Hat:

* components/ - apps, services, builds, tls configurations, etc.
* environments/ - environment-specific configuration details, refered to as overlays.

Most directories have a kustomization.yaml file that determines how the files in directory should be assembled. Each kustomization file can be built individually.

    kustomize build bases/components/apps/postgresql

Notice that manifests are generated for all resources a functioning instance of PostgreSQL needs. These include secrets, storage, config maps, deployments and the back up job. See the kustomization file in the postgresql for more details.

The beauty in Kustomize reveals itself when invoked with an overlay. Overlays are where we pull in multiple bases and can alter parts of the manifests for specific environments. 

    kustomize build environments/overlays/dev

### Secrets

[Secrets](https://kubernetes.io/docs/concepts/configuration/secret/) are how we send small amounts of sensitive data to OpenShift. The sensitive data is base64-encoded before being sent to the cluster to ensure special characters do not inadvertently affect the client or clusters. 

As we don't yet have a better option (stay tuned - CyberArk may come into play here), secrets will be generated from plain-text files that site alongside manifests in this ops repo. These files (private keys, certificates, passwords, etc.) are excluded from the repo for security purposes so whether created anew or unzipped from a backup, they will be ignored by Git. See .gitignore in repo root for details. 
  
A simple development stack can be instantiated with just a few secrets, namely, the Django SECRET_KEY and PostgreSQL passwords. The secrets, along with notes about each are below.

* bases/components/apps/app-name/secrets.env
    * These variables will be injected into your application's container. One variable per line, e.g., Django's SECRET_KEY). SECRET_KEY is the only required piece of data.
* environments/overlays/dev|stage|prod/postgresql-secrets.env
    * These files should contain POSTGRESQL_PASSWORD and (optionally) POSTGRESQL_ADMIN_PASSWORD. Each time a database pod is deployed, the password will be reset to the value supplied. See [image documentation](https://github.com/sclorg/postgresql-container) for more details. These are required.    
* components/tls/base/certs/app-domain/cert|key
    * The certificate and key used by both the app and the media proxy for all environments. Required if you wish to use a custom domain name. 
* environments/overlays/image-promotion/.dockercfg
    * This file, extracted from a service account created in the dev environment, will allow synchronization of images streams across clusters. See [Stage/Prod Image Promotion](#stageprod-image-promotion) below for additional details. Required to set up multi-cluster sync.
* bases/components/builds/app-name/ssh-privatekey - this key allows OpenShift to clone from a private repository on Github. See [Github docs](https://docs.github.com/en/developers/overview/managing-deploy-keys) for information on generating the key. This is only required if your code is stored in a private repo.

It's a good idea to back the secret source files up and store them in a secure location. Once the basic secrets are in place (and whenever they are updated), the files can be archived to a tar file outside of the repository with the two commands below. Change <backup-dir> accordingly.

    find . -type f \( -name "*.env" -o -name ".dockercfg" \) | tar cf <backup-dir>/secrets.tar -T -
    find . -type d -name certs | tar -rf <backup-dir>/secrets.tar -T -

To set up the management area from scratch, e.g., on a new computer, clone this repo then restore the secret sources files to the appropriate locations using this command from the root of the repository.

    tar xvf <backup-dir>/secrets.tar

### Generating the OpenShift Manifests

Once the required secret source files are in place and the kustomization.yaml files have been updated, all of the manifests for a given environment can be generated with Kustomize, using a command from the repo root. E.g., for the dev environment:

    kustomize build environments/overlays/dev

The manifests will be sent to standard out (i.e., the terminal window). When making changes, it's a good idea to pipe the output through `oc apply --dry-run=client -f -` to check for valid YAML and other potential issues.

    kustomize build environments/overlays/dev | oc apply --dry-run=client -f -

In order to apply these manifests to a Kubernetes or OpenShift cluster, log in to the cluster in a terminal by first logging in to the web console (links above) and then using the "Copy Login Command" link in the user menu (top right of screen) to get the login command and token. This process will need to be repeated each time you log in until we set up a more convenient mechanism.

Once you are logged in on the command line, you can apply the manifests with the following command:

    kustomize build environments/overlays/dev | oc apply -f - --prune --all

Unchanged resources will ignored by OpenShift when they are applied. Builds including updated secrets or config maps will result in the creation of new resources with a hash, based on the contents, appended to the resource name. All references to those resources e.g. deployments will be updated with the new hash. You will notice the hash appended to config maps, secrets and their references will change when the content of a config map or secret changes. The `--prune --all` options will remove the old, unused resources. As one would expect, a change to a deployment will result in a new rollout.

Note that one could build and apply the manifests in one command since the `oc` command also supports Kustomize via -k just as `kubectl` does.

    oc apply -k environments/overlays/dev --prune --all

Each kustomize environment declares the namespace for its resources to prevent the application of manifests to the wrong environment. E.g., the dev manifests in the prod environment.

### Building and Deploying New Application Images

To build a new version of the Django application based on a specific tag or commit, which is the normal process for releases, log in to the cluster on the command line (see above for details), then run:

    oc start-build -F app-name [--commit=<branch, tag or commit id>]

The `-F` in the command above will follow the log. When the build is complete, the image will be pushed to the internal registry and the ImageStream's `latest` tag will be updated to point to it. The commit argument is optional. If not specified, the image will be built using the latest commit on the branch in the build config.

Each environment's Django and Celery deployments have a trigger on ImageStream tags so that when the tag is updated, a new deployment will occur. Dev is setup with triggers on `latest`, stage on `stage` and prod on `prod`. The effect of this setup is that newly built images will roll out to the dev environment as soon as the build finishes.

### Stage/Prod Image Promotion

Best practice currently dictates that images are built once, in the dev environment, and synchronized to the other clusters. This repo includes a Kustomize file to generate a `kubernetes.io/dockercfg` secret that will allow stage and prod to connect to the dev image registry, where the images the [build config](./bases/components/builds/) generates will be stored. The secret is generated using data from a service account on the dev cluster. The setup process is documented in the [image-promotion](./environments/overlays/image-promotion/) subdirectory of this repo. 

To promote an image from the dev environment to stage, for example, run:

    oc tag app-name:latest app-name:stage

This command will point the `stage` tag at the `latest` tag. When the stage cluster synchronizes its images with dev, that tag will be updated. Since the deployments in the stage environment have a trigger on the tag, when the tag changes, the new image will be rolled out. The same applies to the prod environment.

For prod releases, the process could include tagging the image with a release tag, e.g.

    oc tag app-name:latest app-name:v0.1.0
    oc tag app-name:v0.1.0 app-name:prod

Note that a cluster-wide setting currently sets the ImageStream sync frequency at 15 minutes. This means it may take up to 15 minutes for the new image tag to show up on stage/prod.

### Quotas

The standard quota setup for projects is 1 CPU and 4Gb RAM, cumulatively. In each deployment, we declare the requested CPU/RAM and the limit for each. OpenShift will start the pods with the requested amount and allow resource consumption to grow until it reaches the limit. 

The deployment manifests are configured to squeeze the entire stack into that space. The requests and limits are based on real-world usage in a Django application on OpenShift. If you make changes to the resource allowances or add/alter deployments, you may need to adjust the resource requests and limits. This often requires a little trial and error.