#!/bin/bash

### Combined Kubernetes installation and setup script
### This script combines k8s-install.sh and k8s-setup.sh functionality

set -e  # Exit on any error

echo "################################################"
echo "Starting combined Kubernetes installation and setup"
echo "################################################"

# Phase 1: Installation (from k8s-install.sh)
echo "Phase 1: Installing microk8s..."
sudo snap install microk8s --classic --channel=1.30

# Allow user to run microk8s commands
sudo usermod -a -G microk8s $USER

# Allow user to gain access to the .kube caching directory
mkdir -p ../.kube
chmod 0700 ../.kube

echo "Installation complete. User added to microk8s group."
echo "Note: You may need to log out and back in for group changes to take effect."

# Phase 2: Setup (from k8s-setup.sh with group handling)
echo "################################################"
echo "Phase 2: Setting up microk8s environment..."
echo "################################################"

# Function to run microk8s commands with proper group context
run_with_microk8s() {
    sg microk8s -c "$1"
}

# Wait for microk8s to be ready
run_with_microk8s "microk8s status --wait-ready"

# Installation of add-ons
echo "Enabling microk8s add-ons..."
run_with_microk8s "microk8s enable host-access"
run_with_microk8s "microk8s enable hostpath-storage"
run_with_microk8s "microk8s enable dns"
run_with_microk8s "microk8s enable ingress"

# Set up MetalLB for dynamic IP range
echo "Setting up MetalLB..."
HOST_IP=$(hostname -I | awk '{print $1}')
METALLB_START=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".240"}')
METALLB_END=$(echo "$HOST_IP" | awk -F. '{print $1"."$2"."$3".250"}')

# Enable MetalLB with dynamic IP range
run_with_microk8s "microk8s enable metallb:${METALLB_START}-${METALLB_END}"

# Clean up any existing TUN devices that might cause conflicts
echo "Cleaning up existing TUN devices..."
sudo ip link delete ogstun 2>/dev/null || echo "No existing ogstun device to clean up"

# Using helm charts to set up environment (open5gs and UERANSIM)
echo "Setting up namespace and helm charts..."
run_with_microk8s "microk8s kubectl create namespace playground"
run_with_microk8s "microk8s kubectl config set-context --current --namespace=playground"

# Check if my-open5gs helm release already exists
if run_with_microk8s "microk8s helm list -n playground" | grep -q "my-open5gs"; then
    echo "################################################"
    echo "my-open5gs already exists, skipping installation and sleep"
    echo "################################################"
else
    run_with_microk8s "microk8s helm install my-open5gs ../open5gs-2.2.3/open5gs --namespace playground --values ../helms/5gSA-values.yaml"
    echo "################################################"
    echo "Waiting for Open5GS deployments to be ready..."
    echo "################################################"
    
    # Wait for all Open5GS deployments to be ready
    run_with_microk8s "microk8s kubectl wait --for=condition=available --timeout=600s deployment --all -n playground"
    
    # Wait for all pods to be running and ready
    run_with_microk8s "microk8s kubectl wait --for=condition=ready --timeout=300s pod --all -n playground"
    
    echo "Open5GS is ready!"
fi

# Patch UPF deployment for hostPID access (required for Challenge 3)
echo "Patching UPF deployment for hostPID access..."
run_with_microk8s "microk8s kubectl patch deployment my-open5gs-upf -n playground -p '{\"spec\":{\"template\":{\"spec\":{\"hostPID\":true}}}}'"

# Wait for UPF to be ready after patch
echo "Waiting for UPF to stabilize after patch..."
run_with_microk8s "microk8s kubectl rollout status deployment/my-open5gs-upf -n playground --timeout=300s"

# Check if my-ueransim-gnb helm release already exists
if run_with_microk8s "microk8s helm list -n playground" | grep -q "my-ueransim-gnb"; then
    echo "my-ueransim-gnb already exists, skipping installation"
else
    run_with_microk8s "microk8s helm install my-ueransim-gnb ../ueransim-gnb-0.2.6/ueransim-gnb --namespace playground --values ../helms/my-gnb-ues-values.yaml"
fi

# Setting up vulnerable web server
echo "Setting up Docker and web server..."

# Check if Docker is already installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    sudo snap install docker
else
    echo "Docker is already installed"
fi

# Build Docker image
echo "Building Docker image..."
sudo docker build -t my-php-app:1.0.0 ../php1

# Import directly to microk8s
echo "Importing image to microk8s..."
sudo docker save my-php-app:1.0.0 | run_with_microk8s "microk8s ctr image import -"

# Get Endpoint IPs from Kubernetes
ENDPOINT_IPS=$(run_with_microk8s "microk8s kubectl get endpoints my-open5gs-webui -o jsonpath='{.subsets[*].addresses[*].ip}'")
MODIFIED_IPS=$(echo $ENDPOINT_IPS | awk -F'.' '{print $1"."$2"."$3".1"}')

# Generate the values.yaml dynamically
cat <<EOF > ../phpfpm-nginx-chart/values.yaml
namespace: playground
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

# Build the PHP application Docker image
echo "Building PHP application Docker image..."

# Add user to docker group if not already added
sudo usermod -a -G docker $USER || true

# Build with sudo to ensure Docker access
sudo docker build -t my-php-app:1.0.0 ../php1/

# Import the image into microk8s
echo "Importing image into microk8s..."
sudo docker save my-php-app:1.0.0 | run_with_microk8s "microk8s ctr image import -"

# Verify image is available
run_with_microk8s "microk8s ctr images list | grep my-php-app"

# Create admin.conf ConfigMap
echo "Creating admin.conf ConfigMap..."
KUBECONFIG_DATA=$(run_with_microk8s "microk8s config")

cat <<EOF | run_with_microk8s "microk8s kubectl apply -f -"
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-conf
  namespace: playground
data:
  admin.conf: |
$(echo "$KUBECONFIG_DATA" | sed 's/^/    /')
EOF

# Install the helm chart for web server
if run_with_microk8s "microk8s helm list -n playground" | grep -q "phpfpm-nginx-release"; then
    echo "phpfpm-nginx-release already exists, upgrading instead"
    run_with_microk8s "microk8s helm upgrade phpfpm-nginx-release ../phpfpm-nginx-chart --namespace playground"
else
    run_with_microk8s "microk8s helm install phpfpm-nginx-release ../phpfpm-nginx-chart --namespace playground"
fi

# Wait for PHP deployment to be ready
echo "Waiting for PHP application to be ready..."
run_with_microk8s "microk8s kubectl rollout status deployment/phpfpm-nginx-deployment -n playground --timeout=300s"

# Create a cluster admin service account
cat <<EOF | run_with_microk8s "microk8s kubectl apply -f -"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-admin-sa
  namespace: playground
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: cluster-admin-sa
  namespace: playground
---
apiVersion: v1
kind: Secret
metadata:
  name: cluster-admin-token
  namespace: playground
  annotations:
    kubernetes.io/service-account.name: cluster-admin-sa
type: kubernetes.io/service-account-token
EOF

# Wait for token to be generated (with retry logic)
echo "Waiting for service account token to be generated..."
for i in {1..12}; do
    if run_with_microk8s "microk8s kubectl get secret cluster-admin-token -n playground -o jsonpath='{.data.token}'" 2>/dev/null | grep -q "."; then
        echo "Token generated successfully"
        break
    fi
    echo "Waiting for token... attempt $i/12"
    sleep 5
done

# Create a restricted service account for the PHP deployment
cat <<EOF | run_with_microk8s "microk8s kubectl apply -f -"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: php-restricted-sa
  namespace: playground
automountServiceAccountToken: false
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: php-restricted-role
  namespace: playground
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["services"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: php-restricted-binding
  namespace: playground
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: php-restricted-role
subjects:
- kind: ServiceAccount
  name: php-restricted-sa
  namespace: playground
EOF

# Get the service account token with retry
echo "Retrieving service account token and CA data..."
for i in {1..6}; do
    TOKEN=$(run_with_microk8s "microk8s kubectl get secret cluster-admin-token -n playground -o jsonpath='{.data.token}'" 2>/dev/null | base64 -d)
    CA_DATA=$(run_with_microk8s "microk8s kubectl get secret cluster-admin-token -n playground -o jsonpath='{.data.ca\.crt}'" 2>/dev/null)
    
    if [ -n "$TOKEN" ] && [ -n "$CA_DATA" ]; then
        echo "Successfully retrieved token and CA data"
        break
    fi
    echo "Token/CA data not ready, retrying... attempt $i/6"
    sleep 5
done

# Verify we have the required data
if [ -z "$TOKEN" ] || [ -z "$CA_DATA" ]; then
    echo "Warning: Could not retrieve service account token or CA data"
    echo "Challenge 1 may not work properly. Continuing with deployment..."
fi

# Use kubernetes service URL
SERVER_URL="https://kubernetes.default.svc.cluster.local:443"

# Create admin.conf ConfigMap
cat <<EOF | run_with_microk8s "microk8s kubectl apply -f -"
apiVersion: v1
kind: ConfigMap
metadata:
  name: admin-kubeconfig
  namespace: playground
data:
  admin.conf: |
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority-data: ${CA_DATA}
        server: ${SERVER_URL}
      name: microk8s-cluster
    contexts:
    - context:
        cluster: microk8s-cluster
        user: cluster-admin
      name: cluster-admin-context
    current-context: cluster-admin-context
    kind: Config
    preferences: {}
    users:
    - name: cluster-admin
      user:
        token: ${TOKEN}
EOF

# Patch PHP deployment with kubeconfig only (unprivileged)
cat <<EOF > php-kubeconfig-patch.yaml
spec:
  template:
    spec:
      serviceAccountName: php-restricted-sa
      automountServiceAccountToken: false
      containers:
      - name: app
        image: my-php-app:1.0.0
        volumeMounts:
        - name: admin-kubeconfig
          mountPath: /.kube
          readOnly: true
      volumes:
      - name: admin-kubeconfig
        configMap:
          name: admin-kubeconfig
          defaultMode: 0644
EOF

run_with_microk8s "microk8s kubectl patch deployment phpfpm-nginx-deployment -n playground --patch-file php-kubeconfig-patch.yaml"
run_with_microk8s "microk8s kubectl rollout status deployment/phpfpm-nginx-deployment -n playground"

# Clean up temporary patch file
rm -f php-kubeconfig-patch.yaml

# Create flag for Challenge 1
run_with_microk8s "microk8s kubectl create secret generic challenge1-flag -n kube-system --from-literal=flag='k8s-admin{admin_conf_leads_to_cluster_takeover}'" 2>/dev/null || echo "Challenge 1 flag already exists"

# Wait for all deployments to be ready before setting up Challenge 2
echo "Setting up Challenge 2 - Lateral Movement to UPF..."
run_with_microk8s "microk8s kubectl wait --for=condition=available deployment --all -n playground --timeout=300s"

# Setup Challenge 2 flag via kubectl cp (simpler and more reliable)
echo "upf-access{lateral_movement_to_5g_core_complete}" > /tmp/challenge2-flag.txt

# Wait for UPF pod to be ready and copy flag file
for i in {1..12}; do
    UPF_POD=$(run_with_microk8s "microk8s kubectl get pods -n playground | grep upf | grep Running | awk '{print \$1}'" 2>/dev/null || echo "")
    if [ -n "$UPF_POD" ]; then
        echo "Copying Challenge 2 flag to UPF pod: $UPF_POD"
        run_with_microk8s "microk8s kubectl cp /tmp/challenge2-flag.txt $UPF_POD:/tmp/challenge2-flag.txt -n playground" 2>/dev/null && echo "Challenge 2 flag deployed successfully" && break
    fi
    echo "Waiting for UPF pod... attempt $i/12"
    sleep 5
done

# Clean up temporary file
rm -f /tmp/challenge2-flag.txt

# Setup Challenge 3 - Pod Breakout (Host Escape)
echo "Setting up Challenge 3 - Pod Breakout to Host..."

# Create Challenge 3 flag on the host system in /tmp (obvious location)
HOST_FLAG_PATH="/tmp/challenge3-flag.txt"
echo "host-breakout{privileged_container_leads_to_host_compromise}" | sudo tee $HOST_FLAG_PATH > /dev/null
sudo chmod 644 $HOST_FLAG_PATH 2>/dev/null || echo "Challenge 3 flag permissions set"

# Verify UPF pod has the necessary privileges for host breakout
echo "Verifying UPF pod configuration for Challenge 3..."
for i in {1..6}; do
    UPF_POD=$(run_with_microk8s "microk8s kubectl get pods -n playground | grep upf | grep Running | awk '{print \$1}'" 2>/dev/null || echo "")
    if [ -n "$UPF_POD" ]; then
        echo "Found running UPF pod: $UPF_POD"
        
        # Check if UPF pod has hostPID enabled
        HOSTPID_CHECK=$(run_with_microk8s "microk8s kubectl get pod $UPF_POD -n playground -o jsonpath='{.spec.hostPID}'" 2>/dev/null || echo "")
        if [ "$HOSTPID_CHECK" = "true" ]; then
            echo "✓ UPF pod has hostPID enabled - Challenge 3 should work"
        else
            echo "✗ UPF pod does not have hostPID enabled - Challenge 3 may not work"
        fi
        
        # Check if UPF pod is privileged
        PRIVILEGED_CHECK=$(run_with_microk8s "microk8s kubectl get pod $UPF_POD -n playground -o jsonpath='{.spec.containers[0].securityContext.privileged}'" 2>/dev/null || echo "")
        if [ "$PRIVILEGED_CHECK" = "true" ]; then
            echo "✓ UPF pod is privileged - Challenge 3 should work"
        else
            echo "✗ UPF pod is not privileged - Challenge 3 may not work"
        fi
        
        # Copy Challenge 3 hint file
        echo "CHALLENGE 3 HINT: The real flag is on the host system at /tmp/challenge3-flag.txt" > /tmp/challenge3-hint.txt
        echo "You need to ESCAPE this container to access the host filesystem." >> /tmp/challenge3-hint.txt
        echo "ESCAPE TECHNIQUE:" >> /tmp/challenge3-hint.txt
        echo "chroot escape: chroot /proc/1/root /bin/bash" >> /tmp/challenge3-hint.txt
        echo "The /proc/1/root symlink points to the host's root filesystem." >> /tmp/challenge3-hint.txt
        echo "This works because the container can see host processes (hostPID=true)." >> /tmp/challenge3-hint.txt
        
        run_with_microk8s "microk8s kubectl cp /tmp/challenge3-hint.txt $UPF_POD:/tmp/challenge3-hint.txt -n playground" 2>/dev/null || echo "Challenge 3 hint copied"
        
        # Re-copy Challenge 2 flag
        echo "upf-access{lateral_movement_to_5g_core_complete}" > /tmp/challenge2-flag.txt
        run_with_microk8s "microk8s kubectl cp /tmp/challenge2-flag.txt $UPF_POD:/tmp/challenge2-flag.txt -n playground" 2>/dev/null || echo "Challenge 2 flag re-copied"
        
        # Clean up temporary files
        rm -f /tmp/challenge3-hint.txt /tmp/challenge2-flag.txt
        
        echo "Challenge 3 setup completed. Flag is at /tmp/challenge3-flag.txt on HOST."
        echo "UPF container should be deployed with hostPID=true for container escape."
        break
    fi
    echo "Waiting for UPF pod to be ready... attempt $i/6"
    sleep 5
done

echo "################################################"
echo "Combined installation and setup completed successfully!"
echo "################################################"

# Test Section - Verify all challenges are working
echo ""
echo "################################################"
echo "TESTING CHALLENGES - Verifying setup..."
echo "################################################"

# Test Challenge 1 - Kubernetes Admin Access
echo ""
echo "=== Testing Challenge 1: Kubernetes Admin Access ==="
PHP_POD=$(run_with_microk8s "microk8s kubectl get pods -n playground | grep phpfpm-nginx | awk '{print \$1}'" 2>/dev/null || echo "")
if [ -n "$PHP_POD" ]; then
    echo "✓ PHP pod found: $PHP_POD"
    
    # Check if admin.conf is mounted
    ADMIN_CONF_CHECK=$(run_with_microk8s "microk8s kubectl exec $PHP_POD -n playground -- ls -la /.kube/admin.conf" 2>/dev/null || echo "")
    if [ -n "$ADMIN_CONF_CHECK" ]; then
        echo "✓ admin.conf is mounted in PHP container"
        
        # Test kubectl access
        KUBECTL_TEST=$(run_with_microk8s "microk8s kubectl exec $PHP_POD -n playground -- kubectl --kubeconfig=/.kube/admin.conf get nodes" 2>/dev/null || echo "")
        if echo "$KUBECTL_TEST" | grep -q "Ready"; then
            echo "✓ Challenge 1 WORKING: kubectl access from PHP container successful"
        else
            echo "✗ Challenge 1 FAILED: kubectl access not working"
        fi
        
        # Check Challenge 1 flag
        FLAG1_CHECK=$(run_with_microk8s "microk8s kubectl get secret challenge1-flag -n kube-system -o jsonpath='{.data.flag}'" 2>/dev/null | base64 -d 2>/dev/null || echo "")
        if [ -n "$FLAG1_CHECK" ]; then
            echo "✓ Challenge 1 flag exists: $FLAG1_CHECK"
        else
            echo "✗ Challenge 1 flag not found"
        fi
    else
        echo "✗ Challenge 1 FAILED: admin.conf not mounted"
    fi
else
    echo "✗ Challenge 1 FAILED: PHP pod not found"
fi

# Test Challenge 2 - Lateral Movement to UPF
echo ""
echo "=== Testing Challenge 2: Lateral Movement to UPF ==="
UPF_POD=$(run_with_microk8s "microk8s kubectl get pods -n playground | grep upf | grep Running | awk '{print \$1}'" 2>/dev/null || echo "")
if [ -n "$UPF_POD" ]; then
    echo "✓ UPF pod found: $UPF_POD"
    
    # Check Challenge 2 flag
    FLAG2_CHECK=$(run_with_microk8s "microk8s kubectl exec $UPF_POD -n playground -- cat /tmp/challenge2-flag.txt" 2>/dev/null || echo "")
    if echo "$FLAG2_CHECK" | grep -q "upf-access"; then
        echo "✓ Challenge 2 WORKING: Flag found in UPF container"
        echo "✓ Challenge 2 flag: $FLAG2_CHECK"
    else
        echo "✗ Challenge 2 FAILED: Flag not found in UPF container"
    fi
    
    # Test kubectl access from UPF (should work with admin.conf)
    KUBECTL_UPF_TEST=$(run_with_microk8s "microk8s kubectl exec $UPF_POD -n playground -- kubectl --kubeconfig=/.kube/admin.conf get pods -n playground" 2>/dev/null || echo "")
    if echo "$KUBECTL_UPF_TEST" | grep -q "upf"; then
        echo "✓ kubectl access from UPF container working"
    else
        echo "✗ kubectl access from UPF container failed (expected if admin.conf not copied)"
    fi
else
    echo "✗ Challenge 2 FAILED: UPF pod not found"
fi

# Test Challenge 3 - Host Breakout
echo ""
echo "=== Testing Challenge 3: Host Breakout ==="
if [ -n "$UPF_POD" ]; then
    # Check if host flag exists
    HOST_FLAG_CHECK=$(cat /tmp/challenge3-flag.txt 2>/dev/null || echo "")
    if echo "$HOST_FLAG_CHECK" | grep -q "host-breakout"; then
        echo "✓ Challenge 3 flag exists on host: $HOST_FLAG_CHECK"
        
        # Test /proc/1/root access from UPF container
        PROC_ROOT_TEST=$(run_with_microk8s "microk8s kubectl exec $UPF_POD -n playground -- ls -la /proc/1/root/" 2>/dev/null || echo "")
        if echo "$PROC_ROOT_TEST" | grep -q "tmp"; then
            echo "✓ /proc/1/root access working from UPF container"
            
            # Test chroot capability
            CHROOT_TEST=$(run_with_microk8s "microk8s kubectl exec $UPF_POD -n playground -- chroot /proc/1/root /bin/bash -c 'cat /tmp/challenge3-flag.txt'" 2>/dev/null || echo "")
            if echo "$CHROOT_TEST" | grep -q "host-breakout"; then
                echo "✓ Challenge 3 WORKING: chroot escape successful"
                echo "✓ Challenge 3 flag: $CHROOT_TEST"
            else
                echo "✗ Challenge 3 FAILED: chroot escape not working"
            fi
        else
            echo "✗ Challenge 3 FAILED: /proc/1/root not accessible"
        fi
    else
        echo "✗ Challenge 3 FAILED: Host flag not found"
    fi
else
    echo "✗ Challenge 3 FAILED: UPF pod not available for testing"
fi

# Test Web Application
echo ""
echo "=== Testing Web Application ==="
PHP_SVC=$(run_with_microk8s "microk8s kubectl get svc -n playground | grep phpfpm-nginx | awk '{print \$1}'" 2>/dev/null || echo "")
if [ -n "$PHP_SVC" ]; then
    echo "✓ PHP service found: $PHP_SVC"
    
    # Test if test.php is accessible
    TEST_PHP=$(run_with_microk8s "microk8s kubectl exec $PHP_POD -n playground -- ls -la /var/www/html/test.php" 2>/dev/null || echo "")
    if echo "$TEST_PHP" | grep -q "test.php"; then
        echo "✓ test.php exists for RCE testing"
    else
        echo "✗ test.php not found"
    fi
    
    # Test container-info.php
    CONTAINER_INFO=$(run_with_microk8s "microk8s kubectl exec $PHP_POD -n playground -- ls -la /var/www/html/container-info.php" 2>/dev/null || echo "")
    if echo "$CONTAINER_INFO" | grep -q "container-info.php"; then
        echo "✓ container-info.php exists for reconnaissance"
    else
        echo "✗ container-info.php not found"
    fi
else
    echo "✗ Web application FAILED: PHP service not found"
fi

echo ""
echo "################################################"
echo "CHALLENGE SUMMARY:"
echo "################################################"
echo "Challenge 1 (Kubernetes Admin): Access admin.conf from PHP container"
echo "Challenge 2 (Lateral Movement): Move from PHP to UPF container"  
echo "Challenge 3 (Host Breakout): Escape UPF container to host via /proc/1/root"
echo ""
echo "Web Entry Point: Use test.php?cmd= for RCE in PHP container"
echo "Attack Chain: Web RCE → Admin Access → Lateral Movement → Host Breakout"
echo "################################################"

### Troubleshooting commands (commented out):
### If there are errors, upgrading the deployment may work sometimes
### Navigate to installation folder to run the following commands:
# run_with_microk8s "microk8s helm upgrade my-open5gs open5gs-2.2.3/open5gs --namespace playground --values helms/5gSA-values.yaml"
# run_with_microk8s "microk8s helm upgrade my-ueransim-gnb ueransim-gnb-0.2.6/ueransim-gnb --namespace playground --values helms/my-gnb-ues-values.yaml"
# run_with_microk8s "microk8s helm upgrade phpfpm-nginx-release phpfpm-nginx-chart --namespace playground"

### Uninstall helm charts when done OR if errors cannot be fixed:
# run_with_microk8s "microk8s helm uninstall -n playground phpfpm-nginx-release"
# run_with_microk8s "microk8s helm uninstall -n playground my-ueransim-gnb"
# run_with_microk8s "microk8s helm uninstall -n playground my-open5gs" 