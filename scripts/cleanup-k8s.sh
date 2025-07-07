#!/bin/bash

### Cleanup script to revert all changes made by k8s-combined.sh
### This allows for a clean re-run of the installation
### Supports both full and partial cleanup options

set -e  # Exit on any error

echo "################################################"
echo "Cleanup script for k8s-combined.sh changes"
echo "################################################"

# Function to run microk8s commands with proper group context
run_with_microk8s() {
    sg microk8s -c "$1" 2>/dev/null || true
}

# Function to display menu and get user choice
show_menu() {
    echo ""
    echo "Choose cleanup option:"
    echo "1) Partial cleanup (Remove deployments, keep microk8s)"
    echo "2) Full cleanup (Remove everything including microk8s)"
    echo "3) Exit without cleanup"
    echo ""
    read -p "Enter your choice (1-3): " choice
    echo ""
}

# Function for partial cleanup
partial_cleanup() {
    echo "################################################"
    echo "Starting PARTIAL cleanup..."
    echo "################################################"
    
    echo "Cleaning up Challenge 2 resources..."
    run_with_microk8s "microk8s kubectl delete configmap challenge2-flag -n playground" 2>/dev/null || echo "Challenge 2 flag configmap already deleted"
    
    echo "Cleaning up admin kubeconfig..."
    run_with_microk8s "microk8s kubectl delete configmap admin-kubeconfig -n playground" 2>/dev/null || echo "Admin kubeconfig already deleted"
    
    echo "Cleaning up Challenge 1 flag..."
    run_with_microk8s "microk8s kubectl delete secret challenge1-flag -n kube-system" 2>/dev/null || echo "Challenge 1 flag already deleted"
    
    echo "Partial cleanup completed!"

    # Step 2: Uninstall Helm charts
    echo "Step 2: Uninstalling Helm charts..."
    run_with_microk8s "microk8s helm uninstall -n playground phpfpm-nginx-release" || echo "phpfpm-nginx-release not found or already removed"
    run_with_microk8s "microk8s helm uninstall -n playground my-ueransim-gnb" || echo "my-ueransim-gnb not found or already removed"
    run_with_microk8s "microk8s helm uninstall -n playground my-open5gs" || echo "my-open5gs not found or already removed"

    # Step 3: Delete namespace
    echo "Step 3: Deleting namespace..."
    run_with_microk8s "microk8s kubectl delete namespace playground" || echo "Namespace playground not found or already removed"

    # Step 3: Remove Docker images
    echo "Step 3: Removing Docker images..."
    sudo docker rmi my-php-app:1.0.0 2>/dev/null || echo "Docker image my-php-app:1.0.0 not found"
    run_with_microk8s "microk8s ctr images rm docker.io/library/my-php-app:1.0.0" || echo "microk8s image not found"

    # Step 4: Clean up generated files
    echo "Step 4: Cleaning up generated files..."
    rm -f ../phpfpm-nginx-chart/values.yaml 2>/dev/null || echo "phpfpm-nginx-chart values.yaml not found"

    echo "################################################"
    echo "PARTIAL cleanup completed successfully!"
    echo "################################################"
    echo "microk8s is still installed and ready for re-deployment."
    echo "You can now re-run k8s-combined.sh (it will skip microk8s installation)."
}

# Function for full cleanup
full_cleanup() {
    echo "################################################"
    echo "Starting FULL cleanup..."
    echo "################################################"
    
    # First do partial cleanup
    echo "Performing partial cleanup first..."
    
    echo "Cleaning up Challenge 2 resources..."
    run_with_microk8s "microk8s kubectl delete configmap challenge2-flag -n playground" 2>/dev/null || echo "Challenge 2 flag configmap already deleted"
    
    echo "Cleaning up admin kubeconfig..."
    run_with_microk8s "microk8s kubectl delete configmap admin-kubeconfig -n playground" 2>/dev/null || echo "Admin kubeconfig already deleted"
    
    echo "Cleaning up Challenge 1 flag..."
    run_with_microk8s "microk8s kubectl delete secret challenge1-flag -n kube-system" 2>/dev/null || echo "Challenge 1 flag already deleted"
    
    echo "Partial cleanup completed!"

    # Step 2: Uninstall Helm charts
    echo "Step 2: Uninstalling Helm charts..."
    run_with_microk8s "microk8s helm uninstall -n playground phpfpm-nginx-release" || echo "phpfpm-nginx-release not found or already removed"
    run_with_microk8s "microk8s helm uninstall -n playground my-ueransim-gnb" || echo "my-ueransim-gnb not found or already removed"
    run_with_microk8s "microk8s helm uninstall -n playground my-open5gs" || echo "my-open5gs not found or already removed"

    # Step 3: Delete namespace
    echo "Step 3: Deleting namespace..."
    run_with_microk8s "microk8s kubectl delete namespace playground" || echo "Namespace playground not found or already removed"

    # Step 3: Remove Docker images
    echo "Step 3: Removing Docker images..."
    sudo docker rmi my-php-app:1.0.0 2>/dev/null || echo "Docker image my-php-app:1.0.0 not found"
    run_with_microk8s "microk8s ctr images rm docker.io/library/my-php-app:1.0.0" || echo "microk8s image not found"

    # Step 4: Disable microk8s add-ons (in reverse order)
    echo "Step 4: Disabling microk8s add-ons..."
    run_with_microk8s "microk8s disable metallb" || echo "MetalLB already disabled"
    run_with_microk8s "microk8s disable ingress" || echo "Ingress already disabled"
    run_with_microk8s "microk8s disable dns" || echo "DNS already disabled"
    run_with_microk8s "microk8s disable hostpath-storage" || echo "Hostpath-storage already disabled"
    run_with_microk8s "microk8s disable host-access" || echo "Host-access already disabled"

    # Step 5: Stop microk8s
    echo "Step 5: Stopping microk8s..."
    run_with_microk8s "microk8s stop" || echo "microk8s already stopped"

    # Step 6: Remove microk8s completely
    echo "Step 6: Removing microk8s..."
    sudo snap remove microk8s || echo "microk8s snap not found"

    # Step 7: Remove user from microk8s group
    echo "Step 7: Removing user from microk8s group..."
    sudo deluser $USER microk8s 2>/dev/null || echo "User not in microk8s group"

    # Step 8: Clean up directories and files
    echo "Step 8: Cleaning up directories and files..."
    rm -rf ../.kube 2>/dev/null || echo ".kube directory not found"
    rm -f ../phpfpm-nginx-chart/values.yaml 2>/dev/null || echo "phpfpm-nginx-chart values.yaml not found"

    # Step 9: Optional - Remove Docker (keeping it installed by default)
    echo "Step 9: Docker cleanup (keeping Docker installed)..."
    echo "Note: Docker is kept installed. To remove it manually run: sudo snap remove docker"

    # Step 10: Clean up any remaining snap data
    echo "Step 10: Cleaning up snap data..."
    sudo rm -rf /var/snap/microk8s 2>/dev/null || echo "No microk8s snap data found"

    echo "################################################"
    echo "FULL cleanup completed successfully!"
    echo "################################################"
    echo "Everything has been removed. You can now re-run k8s-combined.sh for a fresh installation."
    echo ""
    echo "Note: You may need to log out and back in for group changes to take effect."
    echo "If you encounter permission issues, run: newgrp $USER"
}

# Main script logic
if [[ $# -eq 1 ]]; then
    # Command line argument provided
    case $1 in
        --partial|-p)
            partial_cleanup
            ;;
        --full|-f)
            full_cleanup
            ;;
        --help|-h)
            echo "Usage: $0 [OPTION]"
            echo ""
            echo "Options:"
            echo "  -p, --partial    Partial cleanup (remove deployments, keep microk8s)"
            echo "  -f, --full       Full cleanup (remove everything including microk8s)"
            echo "  -h, --help       Show this help message"
            echo ""
            echo "If no option is provided, an interactive menu will be shown."
            exit 0
            ;;
        *)
            echo "Invalid option: $1"
            echo "Use --help for usage information."
            exit 1
            ;;
    esac
else
    # Interactive mode
    show_menu
    case $choice in
        1)
            partial_cleanup
            ;;
        2)
            full_cleanup
            ;;
        3)
            echo "Exiting without cleanup."
            exit 0
            ;;
        *)
            echo "Invalid choice. Exiting."
            exit 1
            ;;
    esac
fi 