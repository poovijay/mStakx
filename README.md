# Create Kubernetes cluster on GCP using Ansible and Terraform
Take home test for DevOps/SysOps role - Level 3


Clone the repository - https://github.com/poovijay/mStakx.git

cd k8s-on-gce


Configure Google cloud credentials. Download the adc.json file and copy it to the app directory.



Modify the profile file to define the project, region, and Google Cloud zone to use:

export GCLOUD_PROJECT=mstakx-test

export GCLOUD_REGION= # Example us-west1

export GCLOUD_ZONE= # Example us-west1-c




Run the command ./in.sh which will launch a docker container with the necessary tools.


Run ./create.sh to roll out the steps necessary to create the cluster.


A ssh key pair is created to access the VMs.


Terraform is used to create the following resources - Virtual machines, Network configuration, Firewall rules, Load balancer to access the cluster.


Description of these resources is present in the file provisioning / kube.tf


The terraform init command initializes the Terraform environment and will download the plugins related to Google Cloud Platform.
certs: The creation of the certificates used to secure and authenticate the accesses between the different components and from outside the cluster.


kubeconfig: The generation of the configuration used by kubelet and kube-proxy on each of the workers.


encryption:  The generation of a key used to encrypt the Kubernetes Secrets of the cluster.


ansible: To generate the inventory of the machines on which the deployment will take place.


etcd: Launch Ansible playbook that will deploy etcd on each controller node of the cluster.


kube-controller: Deploy the controller components kube-apiserver, kube-controller-manager, kube-scheduler via an Ansible playbook.


kubelet: has the workers deployment playbook responsible for creating kubelet, kube-proxy, cry-containerd.


kubectl: responsible for pointing to the cluster and use the right certificates.


network-conf: allows to configure routes used by the pods to communicate.


kube-dns: allows access to services directly by their name from within the cluster.





#Usage -
Put your adc.json in the app dir (See Gcloud account for details on this file).

Adapt profile to match desired region, zone and project.

Launch ./in.sh, it will build a docker image and launch a container with all needed tools.

In the container, launch ./create.sh and wait for ~10mins.
