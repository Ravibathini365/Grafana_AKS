#! /bin/bash

#Login to Artifactory
if docker login vscojfrogrhel.vsazure.com/infra-images -u admin -p 'P1(kl3s4u'
then
    echo "Login to Artifactory (vscojfrogrhel.vsazure.com) is Successful"
else
   echo "Login to Artifactory (vscojfrogrhel.vsazure.com) is Failed, please check with Infra team"
   exit 1
fi

#Getting the list of docker images in jenkins machine
echo "fetching the list of docker images in jenkins machine"
docker images -a

#Removing all the images in jenkins machine
echo "Removing all the images from jenkins machine"
docker rmi $(docker images -q) -f > /dev/null 2>&1

#Pulling the RHEL base image from our artifactory
docker pull vscojfrogrhel.vsazure.com/rhel-ubi-images/ubi8:latest
if [ `echo $?` == 0 ]
then
    echo "Able to pull the RHEL base image from Artifactory"
else
    echo "Unable to pull the RHEL base image from Artifactory, please check with Infra team"
    exit 1
fi

#Grafana package check
ls -l grafana-8.3.4.linux-amd64.tar.gz
if [ `echo $?` == 0 ]
then
    echo "Grafana tar file is already available"
else
    wget https://vscojfrog.vsazure.com/artifactory/oc-infra-local/grafana-8.3.4.linux-amd64.tar.gz > /dev/null 2>&1
    if [ `echo $?` == 0 ]
    then
        echo "Able to pull the Grafana package from Artifactory"
    else
        echo "Unable to pull the Grafana package from Artifactory, please check with Infra team"
        exit 1
    fi
fi

#Untar the Grafana package
echo "Untaring the Grafana package"
tar -xvf grafana-8.3.4.linux-amd64.tar.gz

#Building Grafana image in jenkins machine
docker build -t grafana .
docker images | grep grafana
if [ `echo $?` == 0 ]
then
    echo "Grafana image successfully created"
else
    echo "Unable to build the Grafana image - please check the Docker file and RHEL image"
    exit 1
fi

#Tagging and pushing the docker image
docker tag grafana vscojfrogrhel.vsazure.com/infra-images/grafana
docker push vscojfrogrhel.vsazure.com/infra-images/grafana

#Connect to AKS-cluster
az aks get-credentials --name vs-etocore-aks-infra --resource-group vs-etocore-eastus2-rg 

#Check for the old running pods
kubectl get pods -o wide -n monitoring | grep -w 'grafana'
if [ `echo $?` == 0 ]
then 
    echo "Deleting the old pods"
    kubectl scale --replicas=0 deployment/grafana -n monitoring ; sleep 15
    kubectl get pods -o wide -n monitoring | grep grafana
    if [ `echo $?` == 0 ]
    then 
        echo "Unable to delete the pods - please check if kubelet service is running"
        exit 1
    else
        echo "Successfully deleted the old pods"
    fi
else
    echo "No running pods found"
fi



#Deleting the script fle from jenkins machine
rm -f grafana-deploy.sh
rm -f centos_8.tar.gz*
rm -f grafana-8.3.4.linux-amd64.tar.gz

#Deploying the new pods from new docker image
kubectl apply -f grafana-aks-deploy.yaml
kubectl scale --replicas=1 deployment/grafana -n monitoring ; sleep 15
sleep 15
kubectl get pods -o wide -n monitoring | grep -w 'grafana'
