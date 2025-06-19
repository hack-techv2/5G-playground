# Prerequisites
Get ready an Ubuntu VM with 
- **at least 40GB of storage.**
- **at least 8GB of RAM**
- **at least 4 cores**

Highly recommended to have a **clean snapshot of the VM** before proceeding with the installation.  
 
Clone the GitHub project

```
git clone https://github.com/hack-techv2/5G-playground.git
```
# Installation
1. Give yourself execution rights to the installation scripts

```
chmod +x ./5G-playground/scripts/k8s-install.sh ./5G-playground/scripts/k8s-setup.sh ./5G-playground/scripts/ctfd-install.sh ./5G-playground/scripts/ctfd-setup.sh
```

2. Run the four installation scripts from the /scripts folder.
```
cd ./5G-playground/scripts && ./k8s-install.sh; ./k8s-setup.sh; ./ctfd-install.sh; ./ctfd-setup.sh
```
<blockquote id="bkmrk-note%3A-the-ctfd-insta">
<p id="bkmrk-note%3A-the-ctfd-scrip">NOTE: The ctfd-install script does NOT terminate. Read the output in the terminal to determine when the containers are up.&nbsp;</p>
<p>Should be able to see "ctfd-ctfd-1 &nbsp; | db is ready" message.&nbsp;</p>
</blockquote>

3. Access CTFd platform through a browser with <a href="http://127.0.0.1:8000">http://127.0.0.1:8000</a></p>
The CTFd platform should be accessible through other VMs with http://[serverIP]:8000
<blockquote id="bkmrk-admin-account-is-adm">
<p>Username: admin</p>
<p>Password: admin</p>
</blockquote>
<p id="bkmrk-"><a href="ctfd-1.png" target="_blank" rel="noopener"><img src="https://github.com/hack-techv2/5G-playground/blob/master/Images/ctfd-1.png" alt="Screenshot 2024-09-16 142328.png"></a></p>
Wait for 5-10 min after the installation process has completed for the open5GS setup to be fully functional.

# Validate Installation
## Pods
```
microk8s kubectl get pods -n your-namespace
```
<p id="bkmrk--0"><a href="microk8s-working.png" target="_blank" rel="noopener"><img src="https://github.com/hack-techv2/5G-playground/blob/master/Images/microk8s-working.png" alt="image-1726399892823.png" width="524" height="238"></a></p>

## Microk8s

```
microk8s kubectl get endpoints -A
microk8s kubectl -n your-namespace exec -ti deployment/my-ueransim-gnb-ues -- /bin/bash

# Inside pod
ip a
ping -I uesimtun0 1.1.1.1

# IP should have interface uesimtun0
# Should be able to have WAN connectivity
```

## Open5Gs
```
microk8s kubectl -n your-namespace exec -ti deployment/my-ueransim-gnb-ues -- /bin/bash
```
<p id="bkmrk--1"><a href="open5gs-working.png" target="_blank" rel="noopener"><img src="https://github.com/hack-techv2/5G-playground/blob/master/Images/open5gs-working.png" alt="image-1726408615647.png"></a></p>
After setting up the infrastructure, prepare another Kali VM as the "attacking machine". Ensure connectivity between the Kali and Ubuntu VM.

# Troubleshooting
Try upgrading the Helm deployments

## 5G Network

```
microk8s helm upgrade my-open5gs $(pwd)/5G-playground/open5gs-2.2.3/open5gs --namespace your-namespace --values $(pwd)/5G-playground/helms/5gSA-values.yaml
# Wait for at least 5 minutes before running the script for upgrading the GNB
microk8s helm upgrade my-ueransim-gnb $(pwd)/5G-playground/ueransim-gnb-0.2.6/ueransim-gnb --namespace your-namespace --values $(pwd)/5G-playground/helms/my-gnb-ues-values.yaml
```

## Web Server

```bash
microk8s helm upgrade phpfpm-nginx-release $(pwd)/5G-playground/phpfpm-nginx-chart --namespace your-namespace
```
## Uninstalling and Reinstalling
```
microk8s helm uninstall -n your-namespace phpfpm-nginx-release
microk8s helm uninstall -n your-namespace my-ueransim-gnb
microk8s helm uninstall -n your-namespace my-open5gs
```
Wait for a few minutes before reinstalling the helm charts to ensure proper cleanup by microk8s.
```
microk8s helm install my-open5gs $(pwd)/5G-playground/open5gs-2.2.3/open5gs --namespace your-namespace --values $(pwd)/5G-playground/helms/5gSA-values.yaml
sleep 10s # Best to wait at least 5 minutes before running next command
microk8s helm install my-ueransim-gnb $(pwd)/5G-playground/ueransim-gnb-0.2.6/ueransim-gnb --namespace your-namespace --values $(pwd)/5G-playground/helms/my-gnb-ues-values.yaml
microk8s helm install phpfpm-nginx-release $(pwd)/5G-playground/phpfpm-nginx-chart --namespace your-namespace
```
## Other Errors
Insufficient permissions to access MicroK8s:
```
sudo usermod -a -G microk8s ubu22
sudo chown -R ubu22 ~/.kube
newgrp microk8s
```
When running <code>microk8s kubectl get pods -n your-namespace</code> and faced with the below, the 5G network should not be affected  
```
my-open5gs-populate-f7cc975f5-lh92b        0/1     Unknown   0                20m</code>
```
