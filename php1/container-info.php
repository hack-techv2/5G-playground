<?php
// container-info.php - Container capability and mount information

echo "<h2>Container Security Information</h2>\n";

echo "<h3>User Information:</h3>\n";
echo "<pre>" . shell_exec("id") . "</pre>\n";

echo "<h3>Capabilities:</h3>\n";
echo "<pre>" . shell_exec("cat /proc/self/status | grep Cap") . "</pre>\n";

echo "<h3>Mounted Filesystems:</h3>\n";
echo "<pre>" . shell_exec("mount | grep -E '(host|dev|proc|sys)'") . "</pre>\n";

echo "<h3>Available Directories:</h3>\n";
echo "<pre>" . shell_exec("ls -la / | grep -E '(host|kube)'") . "</pre>\n";

echo "<h3>Process Information:</h3>\n";
echo "<pre>" . shell_exec("ps aux | head -10") . "</pre>\n";

echo "<h3>Network Information:</h3>\n";
echo "<pre>" . shell_exec("ip addr show") . "</pre>\n";

echo "<h3>Kubernetes Context:</h3>\n";
if (file_exists("/.kube/admin.conf")) {
    echo "<p>✅ Kubernetes admin config found at /.kube/admin.conf</p>\n";
    echo "<pre>" . shell_exec("ls -la /.kube/") . "</pre>\n";
} else {
    echo "<p>❌ No Kubernetes config found</p>\n";
}

echo "<h3>Host Filesystem Access:</h3>\n";
if (is_dir("/host")) {
    echo "<p>✅ Host filesystem mounted at /host</p>\n";
    echo "<pre>" . shell_exec("ls -la /host | head -10") . "</pre>\n";
} else {
    echo "<p>❌ No host filesystem access</p>\n";
}

?> 