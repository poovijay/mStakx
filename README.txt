
* Create a Highly available Kubernetes Cluster manually using Google Compute Engine using Kubeadm

Pre-reqs -

1. 3GB or more RAM
2. 3 CPU or more
3. Full Network connectivity among all machines in the cluster
4. Disable SWAP on all nodes
5. Disable SELinux on all nodes

Steps -

1. Create VMs which are part of k8s cluster (Master and Worker nodes)

   1 Master node(master) and 3 Worker nodes(worker1, worker2, worker3)
   centos machine with a minimum of 3GB and 3 CPUs were created
2. Disable SELinux and SWAP on all nodes

   Disable swap on all nodes(Master and Worker nodes) - swapoff -a; it is disabled to improve performance
   Reboot the nodes to ensure that it comes clean
   Remove Swap related entries in /etc/fstab file 

   Disable SELinux on all nodes(Master and Worker nodes) - setenforce 0; it is disabled to allow Master to schedule pods in Worker nodes
   To disable SELinux permanently - sed -i 's/enforcing/disabled/g' /etc/selinux/config
   grep disabled /etc/selinux/config | grep -v '#'
   SELINUX=disabled

3. Install kubeadm, kubelet, kubectl and Docker on all nodes
   -> Start and enable docker and kubelet on all nodes
   
   3a.Install Docker: yum update -y
                      yum install -y docker

   Start and enable Docker: systemctl enable docker
                            systemctl start docker
                            systemctl status docker
   Install and start docker service on all nodes in the cluster.

   3b. Install kubeadm, kubelet, kubectl

       kubeadm - Responsible for bootstrapping your kubernetes cluster
       kubelet - Runs on all machines inside the cluster and manages starting of pods and containers
       kubectl - Command line utility with which cluster can be managed such as deleting, upgrading various kubernetes objects

       The above packages are not available by default in OS repositories. A repo file should be created inside the repos directory. This repo file should have the paths to the location where all the      
       above packages are present.

       Add Kubernetes Repo:
	cat <<EOF > /etc/yum.repos.d/kubernetes.repo
	[kubernetes]
	name=Kubernetes
	baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
	enabled=1
	gpgcheck=1
	repo_gpgcheck=1
	gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
	exclude=kube*
	EOF

       Install kubelet, kubeadm, kubectl and start kubelet:

           yum install -y kubeadm kubelet kubectl --disableexcludes=kubenetes
           systemctl enable kubelet && systemctl start kubelet

       The above should be performed on all Master and Worker nodes.

       Note - Applicable only for RHEL/CentOS 7. Issue occur when traffic is routed incorrectly due to iptables being bypassed.
              cat <<EOF > /etc/sysctl.d/k8s.conf
              net.bridge.bridge-nf-call-ip6tables = 1
              net.bridge.bridge-nf-call-iptables = 1
              EOF
              
              sysctl --system

         echo 1 > /proc/sys/net/ipv4/ip_forward
                
4. Initialize the Master node

   only on *master* node - kubeadm init --pod-network-cidr=10.240.0.0/16 (this is for Flannel pod network add on, if this is ignored then kube-dns pod will not start)
   The output of the above command will have 2 details -

   4a. To start using cluster, you need to run the following as a regular user:
       mkdir -p $HOME/.kube
       sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
       sudo chown $(id -u):$(id -g) $HOME/.kube/config

   4b. Execute the kubeadm join command along with the token on all the worker nodes as root.
5. Configure Pod network

   This is necessary for pods to communicate with each other.

   Only on *master* node: kubectl apply -f \
                          https://raw.githubusercontent.com/coreos/flannel/v0.9.1/Documentation/kube-flannel.yml

   To confirm pod network is installed - kubectl get pods --all-namespaces (check if kube-dns is running)
6. Join Worker nodes to the cluster

   Only on *worker* nodes: kubeadm join --token 

    kubeadm join 10.128.0.7:6443 --token s1u801.z0pr401djuhp9w45 \
    --discovery-token-ca-cert-hash sha256:56824f4e2f47f0efd66e06ac6a04850ad2d15a70aca5e1a8200cfc073b2996a7 

   Note - The Token expires after 24 hours. Create a new one using - kubeadm token create --print-join-command

Testing -

1. kubectl get no

[root@master ~]# kubectl get nodes
NAME      STATUS     ROLES    AGE     VERSION
master    NotReady   master   3m15s   v1.15.0
worker1   NotReady   <none>   55s     v1.15.0
worker2   NotReady   <none>   41s     v1.15.0
worker3   NotReady   <none>   21s     v1.15.0
[root@master ~]# 

* Create CI/CD Pipeline using Jenkins

Configure Cloud Identity and Access Management

Create a Cloud Identity and Access Management (Cloud IAM) service account to delegate permissions to Jenkins. This account enables Jenkins to launch instances in Compute Engine. 

Create a service account

The steps below are executed using Cloud Shell -

1. Create the service account itself: gcloud iam service-accounts create jenkins --display-name jenkins

2. Store the service account email address and your current Google Cloud Platform (GCP) project ID in environment variables for use in later commands: 
   export SA_EMAIL=$(gcloud iam service-accounts list \
    --filter="displayName:jenkins" --format='value(email)')
export PROJECT=$(gcloud info --format='value(config.project)')

3. Bind the following roles to your service account:

    gcloud projects add-iam-policy-binding $PROJECT \
    --role roles/storage.admin --member serviceAccount:$SA_EMAIL
    gcloud projects add-iam-policy-binding $PROJECT --role roles/compute.instanceAdmin.v1 \
    --member serviceAccount:$SA_EMAIL
    gcloud projects add-iam-policy-binding $PROJECT --role roles/compute.networkAdmin \
    --member serviceAccount:$SA_EMAIL
    gcloud projects add-iam-policy-binding $PROJECT --role roles/compute.securityAdmin \
    --member serviceAccount:$SA_EMAIL
    gcloud projects add-iam-policy-binding $PROJECT --role roles/iam.serviceAccountActor \
    --member serviceAccount:$SA_EMAIL

Download the service account key

Now that you've granted the service account the appropriate permissions, you need to create and download its key. Keep the key in a safe place. You'll use it later step when you configure the JClouds plugin to authenticate with the Compute Engine API.

1. Create the key file:

   gcloud iam service-accounts keys create jenkins-sa.json --iam-account $SA_EMAIL

2. Download the file from the console and save it locally.

Installing Jenkins

1. Go to the GCP Marketplace solution for Jenkins.

2. Click Launch on Compute Engine.

3. Change the Machine Type field to 4 vCPUs 15 GB Memory, n1-standard-4.

4. Click Deploy and wait for your Jenkins instance to finish being provisioned.

5. Open your Jenkins instance in the browser by clicking the Site Address link.

6. Log in to Jenkins using the Admin user and Admin password displayed in the details pane.

7. Click Install Suggested Plugins, and then click Restart.

8. Wait for at least one minute, and then refresh the page. Log in with the same username and password you previously used.

Configuring Jenkins plugins

1. In the Jenkins UI, select Manage Jenkins.

2. Click Manage Plugins.

3. Click the Available tab.

4. Use the Filter bar to find the following plugins and select the boxes next to them:
   -> Compute Engine plugin

5. Click Download now and install after restart.

6. Click the Restart Jenkins when installation is complete and no jobs are running checkbox. Jenkins restarts and completes the plugin installations.

Create plugin credentials

1. Log in to Jenkins again, and click Jenkins.

2. Click Credentials.

3. Click System.

4. In the main pane of the UI, click Global credentials (unrestricted).

5. Create the Google credentials:
   -> Click Add Credentials.
   -> Set Kind to Google Service Account from private key.
   -> In the Project Name field, enter your GCP project ID.
   -> Click Choose file.
   -> Select the jenkins-sa.json file that you previously downloaded from Cloud Shell. Click OK.

* Create a Development Namespace

1. vi namespace-dev.json

2. Add the code -

{
  "apiVersion": "v1",
  "kind": "Namespace",
  "metadata": {
    "name": "development",
    "labels": {
      "name": "development"
    }
  }
}

3. kubectl create -f namespace-dev.json

* Create a Monitoring Namespace 

1. vi namespace-monitor.json

2. Add the following code -

{
  "apiVersion": "v1",
  "kind": "Namespace",
  "metadata": {
    "name": "monitoring",
    "labels": {
      "name": "monitoring"
    }
  }
}

3. kubectl create -f namespace-monitor.json

Verify - kubectl get namespaces --show-labels

* Deploy app in development namespace

kubectl run guestbook --image=guestbook --env="POD_NAMESPACE=development"

kubectl get pods

kubectl expose deployment guestbook --type="NodePort" --port=3000

kubectl get service guestbook

* Install and Configure Helm

curl -LO https://git.io/get_helm.sh
chmod 700 get_helm.sh
./get_helm.sh

* Deploy Prometheus and Grafana -

helm search prometheus

helm search grafana

helm inspect values stable/prometheus > /tmp/prometheus.values

To export the service -

nodePort: 32322
type: NodePort

Add the above info in /tmp/prometheus.values

helm install stable/prometheus --name prometheus --values /tmp/prometheus.values --namespace monitoring

watch kubectl get all -n prometheus

Verify : 

kubectl get ns

kubectl get pvc

kubectl get pvc -n prometheus

Grafana -

helm inspect values stable/grafana > /tmp/grafana.values

Change the following values -

type: NodePort
nodePort: 32323

Install: helm install stable/grafana --name grafana --values /tmp/grafana.values --namespace grafana

From the Grafana dashboard - Add a data source -> Prometheus

Settings : Name: Prometheus
           URL: http://worker1:32322
           Access: Browser

           Save and Test

Create a new dashboard: 

Default: Graph
Data source: Prometheus
Choose metrics from the drop down - example: node_load

Optionally, dashboards can be selected from grafana.com/dashboards
Filter by, datasource, Panel type, Category.

Install the custom built dashboards using the ID.
Import the dashboard by clicking on '+' and include the ID/JSON file. Select Prometheus data source. Metrics like Deployment memory usage, Deployment CPU usage, Unavailable replicas can be viewed.
The metrics can be filtered further by viewing it at any individual pod level.
Choose between Garafana, Tiller and other deployments based on preference on the dashboard.

* Monitoring Kubernetes logs using EFK stack

Use Rancher to deploy EFK as a helm chart.

Run Rancher as a docker container.

docker-compose up -d
docker-compose logs -f
Ensure worker nodes can reach Rancher - include the IP address of the worker node in Rancher Server URL
Import the Kubernetes cluster from Rancher Dashboard
Choose EFK from Catalog(Library is enabled by default in Rancher)
Choose between different options - Elasticsearch JVM Heap Size, Elasticsearch Service Type, Elasticsearch Persistent Volume Enabled, Expose Kibana using Layer 7 Load Balancer, Enable Fluent-Bit; Launch

Access Kibana using dashboard
Discover - Create Index pattern, fill in the time filter.
Look at logs from a particular pod by typing its name in the search query field. Add filter if required. Example - If you want to view logs from all pods running in a node, say worker1.
View logs from a pre-defined time range.

on the Kubernetes cluster, kubectl -n efk logs efk-elasticsearch-0




