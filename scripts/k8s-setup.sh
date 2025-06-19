### Code for installing microk8s, run it AFTER k8s-install.sh
microk8s status --wait-ready
# installation of add-ons
microk8s enable host-access
microk8s enable hostpath-storage
microk8s enable dns
microk8s enable ingress

# Set up MetalLB for dynamic IP range
# Get the first IP of the host (assuming it is on the desired interface)
HOST_IP=$(hostname -I | awk '{print $1}')
# Calculate the subnet and create MetalLB IP range (keeping last octet as 240-250)
METALLB_START=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".240"}')
METALLB_END=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".250"}')

# Enable MetalLB with dynamic IP range
microk8s enable metallb:${METALLB_START}-${METALLB_END}

# using helm charts to set up environment (open5gs and UERANSIM)
microk8s kubectl create namespace your-namespace
microk8s kubectl config set-context --current --namespace=your-namespace

# Check if my-open5gs helm release already exists
if microk8s helm list -n your-namespace | grep -q "my-open5gs"; then
    echo "################################################"
    echo "my-open5gs already exists, skipping installation and sleep"
    echo "################################################"
else
    microk8s helm install my-open5gs ../open5gs-2.2.3/open5gs --namespace your-namespace --values ../helms/5gSA-values.yaml
    echo "################################################"
    echo "Sleeping for 360s for open5gs to set up properly"
    echo "################################################"
    sleep 360s
fi

# Check if my-ueransim-gnb helm release already exists
if microk8s helm list -n your-namespace | grep -q "my-ueransim-gnb"; then
    echo "my-ueransim-gnb already exists, skipping installation"
else
    microk8s helm install my-ueransim-gnb ../ueransim-gnb-0.2.6/ueransim-gnb --namespace your-namespace --values ../helms/my-gnb-ues-values.yaml
fi

# setting up of vulnerable web server
# requires building of docker image because github maximum file size is 100MB

# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo snap install docker
else
    echo "Docker is already installed"
fi

# Build Docker image with correct syntax
echo "Building Docker image..."
sudo docker build -t my-php-app:1.0.0 ../php1

# Import directly to microk8s without temporary file
echo "Importing image directly to microk8s..."
sudo docker save my-php-app:1.0.0 | microk8s ctr image import -



# Get Endpoint IPs from Kubernetes
ENDPOINT_IPS=$(microk8s kubectl get endpoints my-open5gs-webui -o jsonpath='{.subsets[*].addresses[*].ip}')
# Replace the last tuple with '1'
MODIFIED_IPS=$(echo $ENDPOINT_IPS | awk -F'.' '{print $1"."$2"."$3".1"}')

# Generate the values.yaml dynamically
cat <<EOF > ../phpfpm-nginx-chart/values.yaml
namespace: your-namespace
phpImage:
  repository: my-php-app
  tag: 1.0.0
nginxImage:
  repository: nginx
  tag: 1.7.9
service:
  type: ClusterIP
  port: 80
  targetPort: 80
ingress:
  enabled: true
  whitelist: "$HOST_IP/32,$MODIFIED_IPS/24"
  host: my-php-app.local
EOF

# actually installing the helm chart for web server
# Check if phpfpm-nginx-release helm release already exists
if microk8s helm list -n your-namespace | grep -q "phpfpm-nginx-release"; then
    echo "phpfpm-nginx-release already exists, upgrading instead"
    microk8s helm upgrade phpfpm-nginx-release ../phpfpm-nginx-chart --namespace your-namespace
else
    microk8s helm install phpfpm-nginx-release ../phpfpm-nginx-chart --namespace your-namespace
fi


### if there are errors, upgrading the deployment may work sometimes
###Navigate to installation folder to run the following commands
#microk8s helm upgrade my-open5gs open5gs-2.2.3/open5gs --namespace your-namespace --values helms/5gSA-values.yaml
#microk8s helm upgrade my-ueransim-gnb ueransim-gnb-0.2.6/ueransim-gnb --namespace your-namespace --values helms/my-gnb-ues-values.yaml
#microk8s helm upgrade phpfpm-nginx-release phpfpm-nginx-chart --namespace your-namespace


### uninstall helm charts, when done OR if errors cannot be fixed, uninstall and reinstall
#microk8s helm uninstall -n your-namespace phpfpm-nginx-release
#microk8s helm uninstall -n your-namespace my-ueransim-gnb
#microk8s helm uninstall -n your-namespace my-open5gs
