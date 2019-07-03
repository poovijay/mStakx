Prerequisites

Google Cloud Platform

This assignment leverages the Google Cloud Platform to streamline provisioning of the compute infrastructure required to bootstrap a Kubernetes cluster from the ground up. 

Google Cloud Platform SDK-Install the Google Cloud SDK

Configure the gcloud command line utility.

Verify the Google Cloud SDK version is 218.0.0 or higher:

gcloud version

Set a Default Compute Region and Zone

Initialize gcloud - gcloud init

Otherwise set a default compute region: gcloud config set compute/region us-west1

Set a default compute zone: gcloud config set compute/zone us-west1-c

Installing the Client Tools

Install CFSSL - The cfssl and cfssljson command line utilities will be used to provision a PKI Infrastructure and generate TLS certificates.	

wget -q --timestamping \https://pkg.cfssl.org/R1.2/cfssl_linux-amd64 \https://pkg.cfssl.org/R1.2/cfssljson_linux-amd64

chmod +x cfssl_linux-amd64 cfssljson_linux-amd64

mv cfssl_linux-amd64 /usr/local/bin/cfssl

mv cfssljson_linux-amd64 /usr/local/bin/cfssljson

Verify cfssl version 1.2.0 or higher is installed: cfssl version

Install kubectl - wget https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl

chmod +x kubectl

mv kubectl /usr/local/bin/

Verification - kubectl version --client 

Ensure the version is 1.12.0 or higher

Provisioning Compute Resources

Kubernetes requires a set of machines to host the Kubernetes control plane and the worker nodes where containers would run. The compute resources would be provisioned here required for running a secure and highly available Kubernetes cluster across a single compute zone.

Virtual Private Cloud Network

A dedicated Virtual Private Cloud (VPC) network will be setup to host the Kubernetes cluster.

Create the kubernetes-the-hard-way custom VPC network: gcloud compute networks create kubernetes-the-hard-way --subnet-mode custom

A subnet must be provisioned with an IP address range large enough to assign a private IP address to each node in the Kubernetes cluster.

Create the kubernetes subnet in the kubernetes-the-hard-way VPC network:

gcloud compute networks subnets create kubernetes \--network kubernetes-the-hard-way \--range 10.240.0.0/24

Firewall Rules

Create a firewall rule that allows internal communication across all protocols:

gcloud compute firewall-rules create kubernetes-the-hard-way-allow-internal \--allow tcp,udp,icmp \--network kubernetes-the-hard-way \--source-ranges 10.240.0.0/24,10.200.0.0/16

[root@oc2717564268 ~]# gcloud compute networks subnets create kubernetes \--network kubernetes-the-hard-way \--range 10.240.0.0/24
Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/regions/us-west1/subnetworks/kubernetes].
NAME        REGION    NETWORK                  RANGE
kubernetes  us-west1  kubernetes-the-hard-way  10.240.0.0/24
[root@oc2717564268 ~]# gcloud compute firewall-rules create kubernetes-the-hard-way-allow-internal \--allow tcp,udp,icmp \--network kubernetes-the-hard-way \--source-ranges 10.240.0.0/24,10.200.0.0/16
Creating firewall...⠧Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/global/firewalls/kubernetes-the-hard-way-allow-internal].                                                         
Creating firewall...done.                                                                                                                                                                                  
NAME                                    NETWORK                  DIRECTION  PRIORITY  ALLOW         DENY  DISABLED
kubernetes-the-hard-way-allow-internal  kubernetes-the-hard-way  INGRESS    1000      tcp,udp,icmp        False
[root@oc2717564268 ~]# 

Create a firewall rule that allows external SSH, ICMP, and HTTPS:

gcloud compute firewall-rules create kubernetes-the-hard-way-allow-external \--allow tcp:22,tcp:6443,icmp \--network kubernetes-the-hard-way \--source-ranges 0.0.0.0/0

Creating firewall...⠧Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/global/firewalls/kubernetes-the-hard-way-allow-external].                                                         
Creating firewall...done.                                                                                                                                                                                  
NAME                                    NETWORK                  DIRECTION  PRIORITY  ALLOW                 DENY  DISABLED
kubernetes-the-hard-way-allow-external  kubernetes-the-hard-way  INGRESS    1000      tcp:22,tcp:6443,icmp        False
[root@oc2717564268 ~]# 

An external load balancer will be used to expose the Kubernetes API Servers to remote clients.

List the firewall rules in the kubernetes-the-hard-way VPC network: gcloud compute firewall-rules list --filter="network:kubernetes-the-hard-way"

NAME                                    NETWORK                  DIRECTION  PRIORITY  ALLOW                 DENY  DISABLED
kubernetes-the-hard-way-allow-external  kubernetes-the-hard-way  INGRESS    1000      tcp:22,tcp:6443,icmp        False
kubernetes-the-hard-way-allow-internal  kubernetes-the-hard-way  INGRESS    1000      tcp,udp,icmp                False

To show all fields of the firewall, please show in JSON format: --format=json
To show all fields in table format, please see the examples in --help.

[root@oc2717564268 ~]# 

Kubernetes Public IP Address

Allocate a static IP address that will be attached to the external load balancer fronting the Kubernetes API Servers:

gcloud compute addresses create kubernetes-the-hard-way \--region $(gcloud config get-value compute/region)

Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/regions/us-west1/addresses/kubernetes-the-hard-way].
[root@oc2717564268 ~]# 

Verify the kubernetes-the-hard-way static IP address was created in default compute region: gcloud compute addresses list --filter="name=('kubernetes-the-hard-way')"

NAME                     ADDRESS/RANGE  TYPE      PURPOSE  NETWORK  REGION    SUBNET  STATUS
kubernetes-the-hard-way  34.83.197.154  EXTERNAL                    us-west1          RESERVED
[root@oc2717564268 ~]# 

Compute Instances

The compute instances will be provisioned using Ubuntu Server 18.04, which has good support for the containerd container runtime. Each compute instance will be provisioned with a fixed private IP address to simplify the Kubernetes bootstrapping process.

Kubernetes Controllers

Create three compute instances which will host the Kubernetes control plane:

for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,controller
done

Instance creation in progress for [controller-0]: https://www.googleapis.com/compute/v1/projects/mstakx-test/zones/us-west1-c/operations/operation-1562088038316-58cb5f6a1b9c2-f1dec8dd-a38af910
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
Instance creation in progress for [controller-1]: https://www.googleapis.com/compute/v1/projects/mstakx-test/zones/us-west1-c/operations/operation-1562088042475-58cb5f6e12fef-423028bf-1f39796d
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
Instance creation in progress for [controller-2]: https://www.googleapis.com/compute/v1/projects/mstakx-test/zones/us-west1-c/operations/operation-1562088045861-58cb5f714d992-df5b13b9-7763c9e4
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
[root@oc2717564268 ~]# 

Kubernetes Workers

Each worker instance requires a pod subnet allocation from the Kubernetes cluster CIDR range. The pod subnet allocation will be used to configure container networking. The pod-cidr instance metadata will be used to expose pod subnet allocations to compute instances at runtime.

The Kubernetes cluster CIDR range is defined by the Controller Manager's --cluster-cidr flag. Here, cluster CIDR range will be set to 10.200.0.0/16, which supports 254 subnets.

Create three compute instances which will host the Kubernetes worker nodes:

for i in 0 1 2; do
  gcloud compute instances create worker-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-1804-lts \
    --image-project ubuntu-os-cloud \
    --machine-type n1-standard-1 \
    --metadata pod-cidr=10.200.${i}.0/24 \
    --private-network-ip 10.240.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags kubernetes-the-hard-way,worker
done

Instance creation in progress for [worker-0]: https://www.googleapis.com/compute/v1/projects/mstakx-test/zones/us-west1-c/operations/operation-1562088263170-58cb60408ba1e-cb67112c-1702af42
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
Instance creation in progress for [worker-1]: https://www.googleapis.com/compute/v1/projects/mstakx-test/zones/us-west1-c/operations/operation-1562088266990-58cb604430449-d4719d8f-8329f254
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
Instance creation in progress for [worker-2]: https://www.googleapis.com/compute/v1/projects/mstakx-test/zones/us-west1-c/operations/operation-1562088270582-58cb60479d341-7bde7e9b-f9f12daa
Use [gcloud compute operations describe URI] command to check the status of the operation(s).
[root@oc2717564268 ~]# 

Verification

List the compute instances in default compute zone: gcloud compute instances list

NAME          ZONE        MACHINE_TYPE   PREEMPTIBLE  INTERNAL_IP  EXTERNAL_IP     STATUS
controller-0  us-west1-c  n1-standard-1               10.240.0.10  34.83.61.176    RUNNING
controller-1  us-west1-c  n1-standard-1               10.240.0.11  35.203.175.161  RUNNING
controller-2  us-west1-c  n1-standard-1               10.240.0.12  35.247.121.146  RUNNING
worker-0      us-west1-c  n1-standard-1               10.240.0.20  35.203.174.39   RUNNING
worker-1      us-west1-c  n1-standard-1               10.240.0.21  34.83.12.161    RUNNING
worker-2      us-west1-c  n1-standard-1               10.240.0.22  35.203.150.236  RUNNING
[root@oc2717564268 ~]# 

Configuring SSH Access

SSH will be used to configure the controller and worker instances. When connecting to compute instances for the first time SSH keys will be generated and stored in the project or instance metadata.

Test SSH access to the controller-0 compute instances: gcloud compute ssh controller-0

[root@oc2717564268 ~]# gcloud compute ssh controller-0
Warning: Permanently added 'compute.6543134076368727176' (ECDSA) to the list of known hosts.
Welcome to Ubuntu 18.04.2 LTS (GNU/Linux 4.15.0-1036-gcp x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

  System information as of Tue Jul  2 17:30:18 UTC 2019

  System load:  0.0                Processes:           87
  Usage of /:   0.6% of 193.66GB   Users logged in:     0
  Memory usage: 5%                 IP address for ens4: 10.240.0.10
  Swap usage:   0%

0 packages can be updated.
0 updates are security updates.



The programs included with the Ubuntu system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Ubuntu comes with ABSOLUTELY NO WARRANTY, to the extent permitted by
applicable law.

root@controller-0:~# 

Type exit at the prompt to exit the controller-0 compute instance: exit

Provisioning a CA and Generating TLS Certificates

A PKI Infrastructure would be provisioned using CloudFlare's PKI toolkit, cfssl, then use it to bootstrap a Certificate Authority, and generate TLS certificates for the following components: etcd, kube-apiserver, kube-controller-manager, kube-scheduler, kubelet, and kube-proxy.

Certificate Authority

Provision a Certificate Authority that can be used to generate additional TLS certificates.

Generate the CA configuration file, certificate, and private key:

{

cat > ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "8760h"
    },
    "profiles": {
      "kubernetes": {
        "usages": ["signing", "key encipherment", "server auth", "client auth"],
        "expiry": "8760h"
      }
    }
  }
}
EOF

cat > ca-csr.json <<EOF
{
  "CN": "Kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "CA",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert -initca ca-csr.json | cfssljson -bare ca

}

2019/07/02 23:24:34 [INFO] generating a new CA key and certificate from CSR
2019/07/02 23:24:34 [INFO] generate received request
2019/07/02 23:24:34 [INFO] received CSR
2019/07/02 23:24:34 [INFO] generating key: rsa-2048
2019/07/02 23:24:34 [INFO] encoded CSR
2019/07/02 23:24:34 [INFO] signed certificate with serial number 142701602005106281990991295062806808779798666915
[root@oc2717564268 ~]# 

Client and Server Certificates

Generate client and server certificates for each Kubernetes component and a client certificate for the Kubernetes admin user.

The Admin Client Certificate

Generate the admin client certificate and private key:

{

cat > admin-csr.json <<EOF
{
  "CN": "admin",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:masters",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  admin-csr.json | cfssljson -bare admin

}

2019/07/02 23:26:26 [INFO] generate received request
2019/07/02 23:26:26 [INFO] received CSR
2019/07/02 23:26:26 [INFO] generating key: rsa-2048
2019/07/02 23:26:26 [INFO] encoded CSR
2019/07/02 23:26:26 [INFO] signed certificate with serial number 74841432516589566701776552023626933479885636500
2019/07/02 23:26:26 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@oc2717564268 ~]# 

The Kubelet Client Certificates

Kubernetes uses a special-purpose authorization mode called Node Authorizer, that specifically authorizes API requests made by Kubelets. 
In order to be authorized by the Node Authorizer, Kubelets must use a credential that identifies them as being in the system:nodes group, with a username of system:node:<nodeName>.

Create a certificate for each Kubernetes worker node that meets the Node Authorizer requirements.

Generate a certificate and private key for each Kubernetes worker node:

for instance in worker-0 worker-1 worker-2; do
cat > ${instance}-csr.json <<EOF
{
  "CN": "system:node:${instance}",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:nodes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

EXTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].accessConfigs[0].natIP)')

INTERNAL_IP=$(gcloud compute instances describe ${instance} \
  --format 'value(networkInterfaces[0].networkIP)')

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=${instance},${EXTERNAL_IP},${INTERNAL_IP} \
  -profile=kubernetes \
  ${instance}-csr.json | cfssljson -bare ${instance}
done

2019/07/02 23:38:54 [INFO] generate received request
2019/07/02 23:38:54 [INFO] received CSR
2019/07/02 23:38:54 [INFO] generating key: rsa-2048
2019/07/02 23:38:54 [INFO] encoded CSR
2019/07/02 23:38:54 [INFO] signed certificate with serial number 395603381823805445286990883502857645836734124027
2019/07/02 23:38:58 [INFO] generate received request
2019/07/02 23:38:58 [INFO] received CSR
2019/07/02 23:38:58 [INFO] generating key: rsa-2048
2019/07/02 23:38:58 [INFO] encoded CSR
2019/07/02 23:38:58 [INFO] signed certificate with serial number 649476836807415991395517771908844115044752388921
2019/07/02 23:39:02 [INFO] generate received request
2019/07/02 23:39:02 [INFO] received CSR
2019/07/02 23:39:02 [INFO] generating key: rsa-2048
2019/07/02 23:39:02 [INFO] encoded CSR
2019/07/02 23:39:02 [INFO] signed certificate with serial number 517360858642600892702147991188521058606330684189
[root@oc2717564268 ~]# 

The Controller Manager Client Certificate

Generate the kube-controller-manager client certificate and private key:

{

cat > kube-controller-manager-csr.json <<EOF
{
  "CN": "system:kube-controller-manager",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-controller-manager",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-controller-manager-csr.json | cfssljson -bare kube-controller-manager

}

2019/07/02 23:41:13 [INFO] generate received request
2019/07/02 23:41:13 [INFO] received CSR
2019/07/02 23:41:13 [INFO] generating key: rsa-2048
2019/07/02 23:41:14 [INFO] encoded CSR
2019/07/02 23:41:14 [INFO] signed certificate with serial number 164569869236817992057667159563731333387595487929
2019/07/02 23:41:14 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@oc2717564268 ~]# 

The Kube Proxy Client Certificate

Generate the kube-proxy client certificate and private key:

{

cat > kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:node-proxier",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-proxy-csr.json | cfssljson -bare kube-proxy

}

2019/07/02 23:42:25 [INFO] generate received request
2019/07/02 23:42:25 [INFO] received CSR
2019/07/02 23:42:25 [INFO] generating key: rsa-2048
2019/07/02 23:42:25 [INFO] encoded CSR
2019/07/02 23:42:25 [INFO] signed certificate with serial number 411004853797321283585981045773257189028062189531
2019/07/02 23:42:25 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@oc2717564268 ~]# 

The Scheduler Client Certificate

Generate the kube-scheduler client certificate and private key:

{

cat > kube-scheduler-csr.json <<EOF
{
  "CN": "system:kube-scheduler",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "system:kube-scheduler",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  kube-scheduler-csr.json | cfssljson -bare kube-scheduler

}

2019/07/02 23:43:41 [INFO] generate received request
2019/07/02 23:43:41 [INFO] received CSR
2019/07/02 23:43:41 [INFO] generating key: rsa-2048
2019/07/02 23:43:41 [INFO] encoded CSR
2019/07/02 23:43:41 [INFO] signed certificate with serial number 50157719898665774669153130972837066316057823256
2019/07/02 23:43:41 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@oc2717564268 ~]# 

The Kubernetes API Server Certificate

The kubernetes-the-hard-way static IP address will be included in the list of subject alternative names for the Kubernetes API Server certificate. This will ensure the certificate can be validated by remote clients.

Generate the Kubernetes API Server certificate and private key:

{

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

cat > kubernetes-csr.json <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -hostname=10.32.0.1,10.240.0.10,10.240.0.11,10.240.0.12,${KUBERNETES_PUBLIC_ADDRESS},127.0.0.1,kubernetes.default \
  -profile=kubernetes \
  kubernetes-csr.json | cfssljson -bare kubernetes

}

2019/07/02 23:46:53 [INFO] generate received request
2019/07/02 23:46:53 [INFO] received CSR
2019/07/02 23:46:53 [INFO] generating key: rsa-2048
2019/07/02 23:46:53 [INFO] encoded CSR
2019/07/02 23:46:53 [INFO] signed certificate with serial number 461108111721305572109608543637903276734924538810

The Service Account Key Pair

The Kubernetes Controller Manager leverages a key pair to generate and sign service account tokens as describe in the managing service accounts documentation.

Generate the service-account certificate and private key:

{

cat > service-account-csr.json <<EOF
{
  "CN": "service-accounts",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "US",
      "L": "Portland",
      "O": "Kubernetes",
      "OU": "Kubernetes The Hard Way",
      "ST": "Oregon"
    }
  ]
}
EOF

cfssl gencert \
  -ca=ca.pem \
  -ca-key=ca-key.pem \
  -config=ca-config.json \
  -profile=kubernetes \
  service-account-csr.json | cfssljson -bare service-account

}

2019/07/02 23:48:31 [INFO] generate received request
2019/07/02 23:48:31 [INFO] received CSR
2019/07/02 23:48:31 [INFO] generating key: rsa-2048
2019/07/02 23:48:31 [INFO] encoded CSR
2019/07/02 23:48:31 [INFO] signed certificate with serial number 251590595700739951549884278677472641125878876769
2019/07/02 23:48:31 [WARNING] This certificate lacks a "hosts" field. This makes it unsuitable for
websites. For more information see the Baseline Requirements for the Issuance and Management
of Publicly-Trusted Certificates, v.1.1.6, from the CA/Browser Forum (https://cabforum.org);
specifically, section 10.2.3 ("Information Requirements").
[root@oc2717564268 ~]# 

Distribute the Client and Server Certificates

Copy the appropriate certificates and private keys to each worker instance:

for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ca.pem ${instance}-key.pem ${instance}.pem ${instance}:~/
done

Warning: Permanently added 'compute.2527707784845602216' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                    100% 1367     5.8KB/s   00:00    
worker-0-key.pem                                                                                                                                                          100% 1679     7.4KB/s   00:00    
worker-0.pem                                                                                                                                                              100% 1493     5.9KB/s   00:00    
Warning: Permanently added 'compute.6903582064154914212' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                    100% 1367     6.1KB/s   00:00    
worker-1-key.pem                                                                                                                                                          100% 1675     7.5KB/s   00:00    
worker-1.pem                                                                                                                                                              100% 1493     6.6KB/s   00:00    
Warning: Permanently added 'compute.6401648262976515489' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                    100% 1367     6.1KB/s   00:00    
worker-2-key.pem                                                                                                                                                          100% 1675     7.1KB/s   00:00    
worker-2.pem                                                                                                                                                              100% 1493     6.7KB/s   00:00    
[root@oc2717564268 ~]# 

Copy the appropriate certificates and private keys to each controller instance:

for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem ${instance}:~/
done

ca.pem                                                                                                                                                                    100% 1367     6.4KB/s   00:00    
ca-key.pem                                                                                                                                                                100% 1679     7.8KB/s   00:00    
kubernetes-key.pem                                                                                                                                                        100% 1679     7.8KB/s   00:00    
kubernetes.pem                                                                                                                                                            100% 1521     6.4KB/s   00:00    
service-account-key.pem                                                                                                                                                   100% 1675     7.4KB/s   00:00    
service-account.pem                                                                                                                                                       100% 1440     6.7KB/s   00:00    
Warning: Permanently added 'compute.4868362045159255173' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                    100% 1367     6.1KB/s   00:00    
ca-key.pem                                                                                                                                                                100% 1679     7.5KB/s   00:00    
kubernetes-key.pem                                                                                                                                                        100% 1679     7.2KB/s   00:00    
kubernetes.pem                                                                                                                                                            100% 1521     6.6KB/s   00:00    
service-account-key.pem                                                                                                                                                   100% 1675     7.3KB/s   00:00    
service-account.pem                                                                                                                                                       100% 1440     6.4KB/s   00:00    
Warning: Permanently added 'compute.1765803616149843073' (ECDSA) to the list of known hosts.
ca.pem                                                                                                                                                                    100% 1367     6.1KB/s   00:00    
ca-key.pem                                                                                                                                                                100% 1679     7.4KB/s   00:00    
kubernetes-key.pem                                                                                                                                                        100% 1679     7.5KB/s   00:00    
kubernetes.pem                                                                                                                                                            100% 1521     6.7KB/s   00:00    
service-account-key.pem                                                                                                                                                   100% 1675     7.4KB/s   00:00    
service-account.pem                                                                                                                                                       100% 1440     6.4KB/s   00:00    
[root@oc2717564268 ~]# 

Generating Kubernetes Configuration Files for Authentication

Generate Kubernetes configuration files, also known as kubeconfigs, which enable Kubernetes clients to locate and authenticate to the Kubernetes API Servers.

Client Authentication Configs

Generate kubeconfig files for the controller manager, kubelet, kube-proxy, and scheduler clients and the admin user.

Kubernetes Public IP Address

Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

Retrieve the kubernetes-the-hard-way static IP address:

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

The kubelet Kubernetes Configuration File

When generating kubeconfig files for Kubelets the client certificate matching the Kubelet's node name must be used. This will ensure Kubelets are properly authorized by the Kubernetes Node Authorizer.

Generate a kubeconfig file for each worker node:

for instance in worker-0 worker-1 worker-2; do
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-credentials system:node:${instance} \
    --client-certificate=${instance}.pem \
    --client-key=${instance}-key.pem \
    --embed-certs=true \
    --kubeconfig=${instance}.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${instance}.kubeconfig

  kubectl config use-context default --kubeconfig=${instance}.kubeconfig
done

Cluster "kubernetes-the-hard-way" set.
User "system:node:worker-0" set.
Context "default" created.
Switched to context "default".
Cluster "kubernetes-the-hard-way" set.
User "system:node:worker-1" set.
Context "default" created.
Switched to context "default".
Cluster "kubernetes-the-hard-way" set.
User "system:node:worker-2" set.
Context "default" created.
Switched to context "default".
[root@oc2717564268 ~]# 

The kube-proxy Kubernetes Configuration File

Generate a kubeconfig file for the kube-proxy service:

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443 \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=kube-proxy.pem \
    --client-key=kube-proxy-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig
}

Cluster "kubernetes-the-hard-way" set.
User "system:kube-proxy" set.
Context "default" created.
Switched to context "default".
[root@oc2717564268 ~]# 

The kube-controller-manager Kubernetes Configuration File

Generate a kubeconfig file for the kube-controller-manager service:

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=kube-controller-manager.pem \
    --client-key=kube-controller-manager-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kube-controller-manager.kubeconfig
}

Cluster "kubernetes-the-hard-way" set.
User "system:kube-controller-manager" set.
Context "default" created.
Switched to context "default".
[root@oc2717564268 ~]# 

The kube-scheduler Kubernetes Configuration File

Generate a kubeconfig file for the kube-scheduler service:

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=kube-scheduler.pem \
    --client-key=kube-scheduler-key.pem \
    --embed-certs=true \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kube-scheduler.kubeconfig
}

Cluster "kubernetes-the-hard-way" set.
User "system:kube-scheduler" set.
Context "default" created.
Switched to context "default".
[root@oc2717564268 ~]# 

The admin Kubernetes Configuration File

Generate a kubeconfig file for the admin user:

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem \
    --embed-certs=true \
    --kubeconfig=admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=admin.kubeconfig

  kubectl config use-context default --kubeconfig=admin.kubeconfig
}

Cluster "kubernetes-the-hard-way" set.
User "admin" set.
Context "default" created.
Switched to context "default".
[root@oc2717564268 ~]# 


Distribute the Kubernetes Configuration Files

Copy the appropriate kubelet and kube-proxy kubeconfig files to each worker instance:

for instance in worker-0 worker-1 worker-2; do
  gcloud compute scp ${instance}.kubeconfig kube-proxy.kubeconfig ${instance}:~/
done

worker-0.kubeconfig                                                                                                                                                       100% 6451    24.2KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                                     100% 6385    19.8KB/s   00:00    
worker-1.kubeconfig                                                                                                                                                       100% 6447    20.4KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                                     100% 6385    20.3KB/s   00:00    
worker-2.kubeconfig                                                                                                                                                       100% 6447    20.5KB/s   00:00    
kube-proxy.kubeconfig                                                                                                                                                     100% 6385    20.2KB/s   00:00    
[root@oc2717564268 ~]# 

Copy the appropriate kube-controller-manager and kube-scheduler kubeconfig files to each controller instance:

for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp admin.kubeconfig kube-controller-manager.kubeconfig kube-scheduler.kubeconfig ${instance}:~/
done

admin.kubeconfig                                                                                                                                                          100% 6329    20.1KB/s   00:00    
kube-controller-manager.kubeconfig                                                                                                                                        100% 6451    20.4KB/s   00:00    
kube-scheduler.kubeconfig                                                                                                                                                 100% 6405    20.3KB/s   00:00    
admin.kubeconfig                                                                                                                                                          100% 6329    20.1KB/s   00:00    
kube-controller-manager.kubeconfig                                                                                                                                        100% 6451    20.5KB/s   00:00    
kube-scheduler.kubeconfig                                                                                                                                                 100% 6405    20.4KB/s   00:00    
admin.kubeconfig                                                                                                                                                          100% 6329    27.1KB/s   00:00    
kube-controller-manager.kubeconfig                                                                                                                                        100% 6451    28.0KB/s   00:00    
kube-scheduler.kubeconfig                                                                                                                                                 100% 6405    20.2KB/s   00:00    
[root@oc2717564268 ~]# 


Generating the Data Encryption Config and Key

Kubernetes stores a variety of data including cluster state, application configurations, and secrets. Kubernetes supports the ability to encrypt cluster data at rest.

Generate an encryption key and an encryption config suitable for encrypting Kubernetes Secrets.

The Encryption Key

Generate an encryption key:

ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

The Encryption Config File

Create the encryption-config.yaml encryption config file:

cat > encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

Copy the encryption-config.yaml encryption config file to each controller instance:

for instance in controller-0 controller-1 controller-2; do
  gcloud compute scp encryption-config.yaml ${instance}:~/
done

encryption-config.yaml                                                                                                                                                    100%  240     0.8KB/s   00:00    
encryption-config.yaml                                                                                                                                                    100%  240     0.8KB/s   00:00    
encryption-config.yaml                                                                                                                                                    100%  240     0.8KB/s   00:00    
[root@oc2717564268 ~]# 

Bootstrapping the etcd Cluster

Kubernetes components are stateless and store cluster state in etcd.
Bootstrap a three node etcd cluster and configure it for high availability and secure remote access.

Prerequisites

Commands must be run on each controller instance: controller-0, controller-1, and controller-2. 

Login to each controller instance using the gcloud command. Example:

gcloud compute ssh controller-0

Bootstrapping an etcd Cluster Member

Download and Install the etcd Binaries

Download the official etcd release binaries from the coreos/etcd GitHub project:

wget -q --show-progress --https-only --timestamping \
  "https://github.com/coreos/etcd/releases/download/v3.3.9/etcd-v3.3.9-linux-amd64.tar.gz"

Extract and install the etcd server and the etcdctl command line utility:

{
  tar -xvf etcd-v3.3.9-linux-amd64.tar.gz
  sudo mv etcd-v3.3.9-linux-amd64/etcd* /usr/local/bin/
}

Configure the etcd Server

{
  sudo mkdir -p /etc/etcd /var/lib/etcd
  sudo cp ca.pem kubernetes-key.pem kubernetes.pem /etc/etcd/
}

The instance internal IP address will be used to serve client requests and communicate with etcd cluster peers. Retrieve the internal IP address for the current compute instance:

INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

Each etcd member must have a unique name within an etcd cluster. Set the etcd name to match the hostname of the current compute instance:

ETCD_NAME=$(hostname -s)

Create the etcd.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/etcd.service
[Unit]
Description=etcd
Documentation=https://github.com/coreos

[Service]
ExecStart=/usr/local/bin/etcd \\
  --name ${ETCD_NAME} \\
  --cert-file=/etc/etcd/kubernetes.pem \\
  --key-file=/etc/etcd/kubernetes-key.pem \\
  --peer-cert-file=/etc/etcd/kubernetes.pem \\
  --peer-key-file=/etc/etcd/kubernetes-key.pem \\
  --trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-trusted-ca-file=/etc/etcd/ca.pem \\
  --peer-client-cert-auth \\
  --client-cert-auth \\
  --initial-advertise-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-peer-urls https://${INTERNAL_IP}:2380 \\
  --listen-client-urls https://${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
  --advertise-client-urls https://${INTERNAL_IP}:2379 \\
  --initial-cluster-token etcd-cluster-0 \\
  --initial-cluster controller-0=https://10.240.0.10:2380,controller-1=https://10.240.0.11:2380,controller-2=https://10.240.0.12:2380 \\
  --initial-cluster-state new \\
  --data-dir=/var/lib/etcd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

Start the etcd Server

{
  sudo systemctl daemon-reload
  sudo systemctl enable etcd
  sudo systemctl start etcd
}

Verification

List the etcd cluster members:

sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.pem \
  --cert=/etc/etcd/kubernetes.pem \
  --key=/etc/etcd/kubernetes-key.pem


Bootstrapping the Kubernetes Control Plane

Bootstrap the Kubernetes control plane across three compute instances and configure it for high availability. Create an external load balancer that exposes the Kubernetes API Servers to remote clients. 
The following components will be installed on each node: Kubernetes API Server, Scheduler, and Controller Manager.

Prerequisites

The following commands should be run on each controller instance: controller-0, controller-1, and controller-2. Login to each controller instance using the gcloud command. 

gcloud compute ssh controller-0

Provision the Kubernetes Control Plane

Create the Kubernetes configuration directory:

sudo mkdir -p /etc/kubernetes/config

Download and Install the Kubernetes Controller Binaries

Download the official Kubernetes release binaries:

wget -q --show-progress --https-only --timestamping \
  "https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-apiserver" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-controller-manager" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-scheduler" \
  "https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl"

Install the Kubernetes binaries:

{
  chmod +x kube-apiserver kube-controller-manager kube-scheduler kubectl
  sudo mv kube-apiserver kube-controller-manager kube-scheduler kubectl /usr/local/bin/
}

Configure the Kubernetes API Server

{
  sudo mkdir -p /var/lib/kubernetes/

  sudo mv ca.pem ca-key.pem kubernetes-key.pem kubernetes.pem \
    service-account-key.pem service-account.pem \
    encryption-config.yaml /var/lib/kubernetes/
}

The instance internal IP address will be used to advertise the API Server to members of the cluster. Retrieve the internal IP address for the current compute instance:

INTERNAL_IP=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/ip)

Create the kube-apiserver.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/kube-apiserver.service
[Unit]
Description=Kubernetes API Server
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-apiserver \\
  --advertise-address=${INTERNAL_IP} \\
  --allow-privileged=true \\
  --apiserver-count=3 \\
  --audit-log-maxage=30 \\
  --audit-log-maxbackup=3 \\
  --audit-log-maxsize=100 \\
  --audit-log-path=/var/log/audit.log \\
  --authorization-mode=Node,RBAC \\
  --bind-address=0.0.0.0 \\
  --client-ca-file=/var/lib/kubernetes/ca.pem \\
  --enable-admission-plugins=Initializers,NamespaceLifecycle,NodeRestriction,LimitRanger,ServiceAccount,DefaultStorageClass,ResourceQuota \\
  --enable-swagger-ui=true \\
  --etcd-cafile=/var/lib/kubernetes/ca.pem \\
  --etcd-certfile=/var/lib/kubernetes/kubernetes.pem \\
  --etcd-keyfile=/var/lib/kubernetes/kubernetes-key.pem \\
  --etcd-servers=https://10.240.0.10:2379,https://10.240.0.11:2379,https://10.240.0.12:2379 \\
  --event-ttl=1h \\
  --experimental-encryption-provider-config=/var/lib/kubernetes/encryption-config.yaml \\
  --kubelet-certificate-authority=/var/lib/kubernetes/ca.pem \\
  --kubelet-client-certificate=/var/lib/kubernetes/kubernetes.pem \\
  --kubelet-client-key=/var/lib/kubernetes/kubernetes-key.pem \\
  --kubelet-https=true \\
  --runtime-config=api/all \\
  --service-account-key-file=/var/lib/kubernetes/service-account.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --service-node-port-range=30000-32767 \\
  --tls-cert-file=/var/lib/kubernetes/kubernetes.pem \\
  --tls-private-key-file=/var/lib/kubernetes/kubernetes-key.pem \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

Configure the Kubernetes Controller Manager

Move the kube-controller-manager kubeconfig into place:

sudo mv kube-controller-manager.kubeconfig /var/lib/kubernetes/

Create the kube-controller-manager.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-controller-manager \\
  --address=0.0.0.0 \\
  --cluster-cidr=10.200.0.0/16 \\
  --cluster-name=kubernetes \\
  --cluster-signing-cert-file=/var/lib/kubernetes/ca.pem \\
  --cluster-signing-key-file=/var/lib/kubernetes/ca-key.pem \\
  --kubeconfig=/var/lib/kubernetes/kube-controller-manager.kubeconfig \\
  --leader-elect=true \\
  --root-ca-file=/var/lib/kubernetes/ca.pem \\
  --service-account-private-key-file=/var/lib/kubernetes/service-account-key.pem \\
  --service-cluster-ip-range=10.32.0.0/24 \\
  --use-service-account-credentials=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

Configure the Kubernetes Scheduler

Move the kube-scheduler kubeconfig into place:

sudo mv kube-scheduler.kubeconfig /var/lib/kubernetes/

Create the kube-scheduler.yaml configuration file:

cat <<EOF | sudo tee /etc/kubernetes/config/kube-scheduler.yaml
apiVersion: componentconfig/v1alpha1
kind: KubeSchedulerConfiguration
clientConnection:
  kubeconfig: "/var/lib/kubernetes/kube-scheduler.kubeconfig"
leaderElection:
  leaderElect: true
EOF

Create the kube-scheduler.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-scheduler \\
  --config=/etc/kubernetes/config/kube-scheduler.yaml \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

Start the Controller Services

{
  sudo systemctl daemon-reload
  sudo systemctl enable kube-apiserver kube-controller-manager kube-scheduler
  sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler
}

Created symlink /etc/systemd/system/multi-user.target.wants/kube-apiserver.service → /etc/systemd/system/kube-apiserver.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-controller-manager.service → /etc/systemd/system/kube-controller-manager.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-scheduler.service → /etc/systemd/system/kube-scheduler.service.
root@controller-2:~# 

Verify -

root@controller-0:~# ETCDCTL_API=3 etcdctl member list \
>   --endpoints=https://127.0.0.1:2379 \
>   --cacert=/etc/etcd/ca.pem \
>   --cert=/etc/etcd/kubernetes.pem \
>   --key=/etc/etcd/kubernetes-key.pem
3a57933972cb5131, started, controller-2, https://10.240.0.12:2380, https://10.240.0.12:2379
f98dc20bce6225a0, started, controller-0, https://10.240.0.10:2380, https://10.240.0.10:2379
ffed16798470cab5, started, controller-1, https://10.240.0.11:2380, https://10.240.0.11:2379
root@controller-0:~# 


Enable HTTP Health Checks

nginx installed and configured to accept HTTP health checks on port 80 and proxy the connections to the API server on https://127.0.0.1:6443/healthz. The /healthz API server endpoint does not require authentication by default.

Install a basic web server to handle HTTP health checks:

sudo apt-get install -y nginx

cat > kubernetes.default.svc.cluster.local <<EOF
server {
  listen      80;
  server_name kubernetes.default.svc.cluster.local;

  location /healthz {
     proxy_pass                    https://127.0.0.1:6443/healthz;
     proxy_ssl_trusted_certificate /var/lib/kubernetes/ca.pem;
  }
}
EOF

{
  sudo mv kubernetes.default.svc.cluster.local \
    /etc/nginx/sites-available/kubernetes.default.svc.cluster.local

  sudo ln -s /etc/nginx/sites-available/kubernetes.default.svc.cluster.local /etc/nginx/sites-enabled/
}

systemctl restart nginx

systemctl enable nginx

Verification -

kubectl get componentstatuses --kubeconfig admin.kubeconfig

root@controller-0:~# kubectl get componentstatuses --kubeconfig admin.kubeconfig
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-2               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}   
etcd-1               Healthy   {"health":"true"}   
root@controller-0:~# 

Test the nginx HTTP health check proxy:

curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz

root@controller-2:~# curl -H "Host: kubernetes.default.svc.cluster.local" -i http://127.0.0.1/healthz
HTTP/1.1 200 OK
Server: nginx/1.14.0 (Ubuntu)
Date: Wed, 03 Jul 2019 04:57:15 GMT
Content-Type: text/plain; charset=utf-8
Content-Length: 2
Connection: keep-alive

okroot@controller-2:~# 

RBAC for Kubelet Authorization

Configure RBAC permissions to allow the Kubernetes API Server to access the Kubelet API on each worker node. Access to the Kubelet API is required for retrieving metrics, logs, and executing commands in pods.

gcloud compute ssh controller-0

Create the system:kube-apiserver-to-kubelet ClusterRole with permissions to access the Kubelet API and perform most common tasks associated with managing pods:

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:kube-apiserver-to-kubelet
rules:
  - apiGroups:
      - ""
    resources:
      - nodes/proxy
      - nodes/stats
      - nodes/log
      - nodes/spec
      - nodes/metrics
    verbs:
      - "*"
EOF



The Kubernetes API Server authenticates to the Kubelet as the kubernetes user using the client certificate as defined by the --kubelet-client-certificate flag.

Bind the system:kube-apiserver-to-kubelet ClusterRole to the kubernetes user:

cat <<EOF | kubectl apply --kubeconfig admin.kubeconfig -f -
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: system:kube-apiserver
  namespace: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:kube-apiserver-to-kubelet
subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: User
    name: kubernetes
EOF

The Kubernetes Frontend Load Balancer

Provision an external load balancer to front the Kubernetes API Servers. The kubernetes-the-hard-way static IP address will be attached to the resulting load balancer.

The compute instances created will not have permission to complete this section. Run the following commands from the same machine used to create the compute instances.

Provision a Network Load Balancer

Create the external load balancer network resources:

{
  KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')

  gcloud compute http-health-checks create kubernetes \
    --description "Kubernetes Health Check" \
    --host "kubernetes.default.svc.cluster.local" \
    --request-path "/healthz"

  gcloud compute firewall-rules create kubernetes-the-hard-way-allow-health-check \
    --network kubernetes-the-hard-way \
    --source-ranges 209.85.152.0/22,209.85.204.0/22,35.191.0.0/16 \
    --allow tcp

  gcloud compute target-pools create kubernetes-target-pool \
    --http-health-check kubernetes

  gcloud compute target-pools add-instances kubernetes-target-pool \
   --instances controller-0,controller-1,controller-2

  gcloud compute forwarding-rules create kubernetes-forwarding-rule \
    --address ${KUBERNETES_PUBLIC_ADDRESS} \
    --ports 6443 \
    --region $(gcloud config get-value compute/region) \
    --target-pool kubernetes-target-pool
}
Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/global/httpHealthChecks/kubernetes].
NAME        HOST                                  PORT  REQUEST_PATH
kubernetes  kubernetes.default.svc.cluster.local  80    /healthz
Creating firewall...⠧Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/global/firewalls/kubernetes-the-hard-way-allow-health-check].                                                     
Creating firewall...done.                                                                                                                                                                                  
NAME                                        NETWORK                  DIRECTION  PRIORITY  ALLOW  DENY  DISABLED
kubernetes-the-hard-way-allow-health-check  kubernetes-the-hard-way  INGRESS    1000      tcp          False
Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/regions/us-west1/targetPools/kubernetes-target-pool].
NAME                    REGION    SESSION_AFFINITY  BACKUP  HEALTH_CHECKS
kubernetes-target-pool  us-west1  NONE                      kubernetes
Updated [https://www.googleapis.com/compute/v1/projects/mstakx-test/regions/us-west1/targetPools/kubernetes-target-pool].
Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/regions/us-west1/forwardingRules/kubernetes-forwarding-rule].
[root@oc2717564268 ~]# 

Verification

Retrieve the kubernetes-the-hard-way static IP address:

KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
  --region $(gcloud config get-value compute/region) \
  --format 'value(address)')

Make a HTTP request for the Kubernetes version info:

[root@oc2717564268 ~]# curl --cacert ca.pem https://${KUBERNETES_PUBLIC_ADDRESS}:6443/version
{
  "major": "1",
  "minor": "12",
  "gitVersion": "v1.12.0",
  "gitCommit": "0ed33881dc4355495f623c6f22e7dd0b7632b7c0",
  "gitTreeState": "clean",
  "buildDate": "2018-09-27T16:55:41Z",
  "goVersion": "go1.10.4",
  "compiler": "gc",
  "platform": "linux/amd64"
}[root@oc2717564268 ~]# 


Bootstrapping the Kubernetes Worker Nodes

Bootstrap three Kubernetes worker nodes. The following components will be installed on each node: runc, gVisor, container networking plugins, containerd, kubelet, and kube-proxy.

The following commands must be run on each worker instance -

worker-0, worker-1, and worker-2. Login to each worker instance using the gcloud command. Example: gcloud compute ssh worker-0

Provisioning a Kubernetes Worker Node

Install the OS dependencies: 

{
  sudo apt-get update
  sudo apt-get -y install socat conntrack ipset
}

The socat binary enables support for the kubectl port-forward command.

Download and Install Worker Binaries

wget -q --show-progress --https-only --timestamping \
  https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.12.0/crictl-v1.12.0-linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-the-hard-way/runsc-50c283b9f56bb7200938d9e207355f05f79f0d17 \
  https://github.com/opencontainers/runc/releases/download/v1.0.0-rc5/runc.amd64 \
  https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz \
  https://github.com/containerd/containerd/releases/download/v1.2.0-rc.0/containerd-1.2.0-rc.0.linux-amd64.tar.gz \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubectl \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kube-proxy \
  https://storage.googleapis.com/kubernetes-release/release/v1.12.0/bin/linux/amd64/kubelet


Create the installation directories:

sudo mkdir -p \
  /etc/cni/net.d \
  /opt/cni/bin \
  /var/lib/kubelet \
  /var/lib/kube-proxy \
  /var/lib/kubernetes \
  /var/run/kubernetes

Install the worker binaries:

{
  sudo mv runsc-50c283b9f56bb7200938d9e207355f05f79f0d17 runsc
  sudo mv runc.amd64 runc
  chmod +x kubectl kube-proxy kubelet runc runsc
  sudo mv kubectl kube-proxy kubelet runc runsc /usr/local/bin/
  sudo tar -xvf crictl-v1.12.0-linux-amd64.tar.gz -C /usr/local/bin/
  sudo tar -xvf cni-plugins-amd64-v0.6.0.tgz -C /opt/cni/bin/
  sudo tar -xvf containerd-1.2.0-rc.0.linux-amd64.tar.gz -C /
}

Configure CNI Networking

Retrieve the Pod CIDR range for the current compute instance:

POD_CIDR=$(curl -s -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/attributes/pod-cidr)

Create the bridge network configuration file:

cat <<EOF | sudo tee /etc/cni/net.d/10-bridge.conf
{
    "cniVersion": "0.3.1",
    "name": "bridge",
    "type": "bridge",
    "bridge": "cnio0",
    "isGateway": true,
    "ipMasq": true,
    "ipam": {
        "type": "host-local",
        "ranges": [
          [{"subnet": "${POD_CIDR}"}]
        ],
        "routes": [{"dst": "0.0.0.0/0"}]
    }
}
EOF


Create the loopback network configuration file:

cat <<EOF | sudo tee /etc/cni/net.d/99-loopback.conf
{
    "cniVersion": "0.3.1",
    "type": "loopback"
}
EOF

Configure containerd

Create the containerd configuration file:

mkdir -p /etc/containerd/

cat << EOF | sudo tee /etc/containerd/config.toml
[plugins]
  [plugins.cri.containerd]
    snapshotter = "overlayfs"
    [plugins.cri.containerd.default_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runc"
      runtime_root = ""
    [plugins.cri.containerd.untrusted_workload_runtime]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
    [plugins.cri.containerd.gvisor]
      runtime_type = "io.containerd.runtime.v1.linux"
      runtime_engine = "/usr/local/bin/runsc"
      runtime_root = "/run/containerd/runsc"
EOF

Untrusted workloads will be run using the gVisor (runsc) runtime.

Create the containerd.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/containerd.service
[Unit]
Description=containerd container runtime
Documentation=https://containerd.io
After=network.target

[Service]
ExecStartPre=/sbin/modprobe overlay
ExecStart=/bin/containerd
Restart=always
RestartSec=5
Delegate=yes
KillMode=process
OOMScoreAdjust=-999
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity

[Install]
WantedBy=multi-user.target
EOF

Configure the Kubelet

{
  sudo mv ${HOSTNAME}-key.pem ${HOSTNAME}.pem /var/lib/kubelet/
  sudo mv ${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
  sudo mv ca.pem /var/lib/kubernetes/
}

Create the kubelet-config.yaml configuration file:

cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.pem"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.32.0.10"
podCIDR: "${POD_CIDR}"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
tlsCertFile: "/var/lib/kubelet/${HOSTNAME}.pem"
tlsPrivateKeyFile: "/var/lib/kubelet/${HOSTNAME}-key.pem"
EOF

The resolvConf configuration is used to avoid loops when using CoreDNS for service discovery on systems running systemd-resolved.

Create the kubelet.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=containerd.service
Requires=containerd.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --container-runtime=remote \\
  --container-runtime-endpoint=unix:///var/run/containerd/containerd.sock \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

Configure the Kubernetes Proxy

 mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

Create the kube-proxy-config.yaml configuration file:

cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "10.200.0.0/16"
EOF

Create the kube-proxy.service systemd unit file:

cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

Start the Worker Services

{
  sudo systemctl daemon-reload
  sudo systemctl enable containerd kubelet kube-proxy
  sudo systemctl start containerd kubelet kube-proxy
}

Created symlink /etc/systemd/system/multi-user.target.wants/containerd.service → /etc/systemd/system/containerd.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kubelet.service → /etc/systemd/system/kubelet.service.
Created symlink /etc/systemd/system/multi-user.target.wants/kube-proxy.service → /etc/systemd/system/kube-proxy.service.
root@worker-2:~# 

Verification

The compute instances created will not have permission to complete this section. Run the following commands from the same machine used to create the compute instances.

List the registered Kubernetes nodes:

gcloud compute ssh controller-0 \
  --command "kubectl get nodes --kubeconfig admin.kubeconfig"

Output -

NAME       STATUS   ROLES    AGE   VERSION
worker-0   Ready    <none>   91s   v1.12.0
worker-1   Ready    <none>   88s   v1.12.0
worker-2   Ready    <none>   85s   v1.12.0
[root@oc2717564268 ~]# 

Configuring kubectl for Remote Access

Generate a kubeconfig file for the kubectl command line utility based on the admin user credentials. The commands should be run from the same directory used to create admin client certificates.

The Admin Kubernetes Configuration File

Each kubeconfig requires a Kubernetes API Server to connect to. To support high availability the IP address assigned to the external load balancer fronting the Kubernetes API Servers will be used.

Generate a kubeconfig file suitable for authenticating as the admin user:

{
  KUBERNETES_PUBLIC_ADDRESS=$(gcloud compute addresses describe kubernetes-the-hard-way \
    --region $(gcloud config get-value compute/region) \
    --format 'value(address)')

  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=ca.pem \
    --embed-certs=true \
    --server=https://${KUBERNETES_PUBLIC_ADDRESS}:6443

  kubectl config set-credentials admin \
    --client-certificate=admin.pem \
    --client-key=admin-key.pem

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}

Verification

Check the health of the remote Kubernetes cluster:

kubectl get componentstatuses

[root@oc2717564268 ~]# kubectl get componentstatuses
NAME                 STATUS    MESSAGE             ERROR
scheduler            Healthy   ok                  
controller-manager   Healthy   ok                  
etcd-1               Healthy   {"health":"true"}   
etcd-2               Healthy   {"health":"true"}   
etcd-0               Healthy   {"health":"true"}   
[root@oc2717564268 ~]# 

List the nodes in the remote Kubernetes cluster:

[root@oc2717564268 ~]# kubectl get nodes
NAME       STATUS   ROLES    AGE     VERSION
worker-0   Ready    <none>   8m23s   v1.12.0
worker-1   Ready    <none>   8m20s   v1.12.0
worker-2   Ready    <none>   8m17s   v1.12.0
[root@oc2717564268 ~]# 

Provisioning Pod Network Routes

Pods scheduled to a node receive an IP address from the node's Pod CIDR range. At this point pods can not communicate with other pods running on different nodes due to missing network routes.

Create a route for each worker node that maps the node's Pod CIDR range to the node's internal IP address.

The Routing Table

Print the internal IP address and Pod CIDR range for each worker instance:

[root@oc2717564268 ~]# for instance in worker-0 worker-1 worker-2; do
>   gcloud compute instances describe ${instance} \
>     --format 'value[separator=" "](networkInterfaces[0].networkIP,metadata.items[0].value)'
> done
10.240.0.20 10.200.0.0/24
10.240.0.21 10.200.1.0/24
10.240.0.22 10.200.2.0/24
[root@oc2717564268 ~]# 

Routes

Create network routes for each worker instance:

[root@oc2717564268 ~]# for i in 0 1 2; do
>   gcloud compute routes create kubernetes-route-10-200-${i}-0-24 \
>     --network kubernetes-the-hard-way \
>     --next-hop-address 10.240.0.2${i} \
>     --destination-range 10.200.${i}.0/24
> done
Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/global/routes/kubernetes-route-10-200-0-0-24].
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP     PRIORITY
kubernetes-route-10-200-0-0-24  kubernetes-the-hard-way  10.200.0.0/24  10.240.0.20  1000
Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/global/routes/kubernetes-route-10-200-1-0-24].
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP     PRIORITY
kubernetes-route-10-200-1-0-24  kubernetes-the-hard-way  10.200.1.0/24  10.240.0.21  1000
Created [https://www.googleapis.com/compute/v1/projects/mstakx-test/global/routes/kubernetes-route-10-200-2-0-24].
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP     PRIORITY
kubernetes-route-10-200-2-0-24  kubernetes-the-hard-way  10.200.2.0/24  10.240.0.22  1000
[root@oc2717564268 ~]# 

List the routes in the kubernetes-the-hard-way VPC network:

gcloud compute routes list --filter "network: kubernetes-the-hard-way"
NAME                            NETWORK                  DEST_RANGE     NEXT_HOP                  PRIORITY
default-route-93134e7e835f7dbb  kubernetes-the-hard-way  0.0.0.0/0      default-internet-gateway  1000
default-route-b739ccc18df4c9cd  kubernetes-the-hard-way  10.240.0.0/24  kubernetes-the-hard-way   1000
kubernetes-route-10-200-0-0-24  kubernetes-the-hard-way  10.200.0.0/24  10.240.0.20               1000
kubernetes-route-10-200-1-0-24  kubernetes-the-hard-way  10.200.1.0/24  10.240.0.21               1000
kubernetes-route-10-200-2-0-24  kubernetes-the-hard-way  10.200.2.0/24  10.240.0.22               1000
[root@oc2717564268 ~]# 

Deploying the DNS Cluster Add-on

Deploy the DNS add-on which provides DNS based service discovery, backed by CoreDNS, to applications running inside the Kubernetes cluster.

The DNS Cluster Add-on

Deploy the coredns cluster add-on:

kubectl apply -f https://storage.googleapis.com/kubernetes-the-hard-way/coredns.yaml
serviceaccount/coredns created
clusterrole.rbac.authorization.k8s.io/system:coredns created
clusterrolebinding.rbac.authorization.k8s.io/system:coredns created
configmap/coredns created
deployment.extensions/coredns created
service/kube-dns created
[root@oc2717564268 ~]# 

List the pods created by the kube-dns deployment:

[root@oc2717564268 ~]# kubectl get pods -l k8s-app=kube-dns -n kube-system
NAME                       READY   STATUS              RESTARTS   AGE
coredns-699f8ddd77-gqzjv   0/1     ContainerCreating   0          85s
coredns-699f8ddd77-nzkp8   1/1     Running             0          85s
[root@oc2717564268 ~]# 

