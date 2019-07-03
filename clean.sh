#!/bin/bash
#
# Script Name: clean.sh
#
# Author: Pooja Vijayaraj
# Date : July 3, 2019
#
# Description: Tears down the K8s cluster
#
# Usage: Must be run as root from the directory which has gcloud command utilities installed. 
#		./"clean.sh"

#Variable
OPTF=/tmp/trail_messages-`date +"%F"-"%R"` ##Output file

   
# Delete the controller and worker compute instances

$echo "`gcloud -q compute instances delete \
  controller-0 controller-1 controller-2 \
  worker-0 worker-1 worker-2`" >> $OPTF


# Delete the external load balancer network resources

{
$echo "`gcloud -q compute forwarding-rules delete kubernetes-forwarding-rule \
    --region $(gcloud config get-value compute/region)`" >> $OPTF

$echo "`gcloud -q compute target-pools delete kubernetes-target-pool`" >> $OPTF

$echo "`gcloud -q compute http-health-checks delete kubernetes`" >> $OPTF

$echo "`gcloud -q compute addresses delete kubernetes-the-hard-way`" >> $OPTF
}

# Delete the kubernetes-the-hard-way firewall rules

$echo "`gcloud -q compute firewall-rules delete \
  kubernetes-the-hard-way-allow-nginx-service \
  kubernetes-the-hard-way-allow-internal \
  kubernetes-the-hard-way-allow-external \
  kubernetes-the-hard-way-allow-health-check`" >> $OPTF

# Delete the kubernetes-the-hard-way network VPC

{
  $echo "`gcloud -q compute routes delete \
    kubernetes-route-10-200-0-0-24 \
    kubernetes-route-10-200-1-0-24 \
    kubernetes-route-10-200-2-0-24`" >> $OPTF

  $echo "`gcloud -q compute networks subnets delete kubernetes`" >> $OPTF

  $echo "`gcloud -q compute networks delete kubernetes-the-hard-way`" >> $OPTF
}

exit 0
