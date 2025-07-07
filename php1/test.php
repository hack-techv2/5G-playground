<?php
// vulnerable.php

// Get the user-supplied input from the query string
$command = $_GET['cmd'];

// Execute the command without proper validation or sanitization
$output = shell_exec($command);

// Display the output of the command
echo "<pre>$output</pre>";
?>
