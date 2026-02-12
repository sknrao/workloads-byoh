#!/bin/bash
# SD-Core NAD Deployment and Verification Script
# This script helps verify NAD setup and troubleshoot common issues

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

NAMESPACE="omec"

echo "========================================"
echo "SD-Core NAD Verification Script"
echo "========================================"
echo ""

# Function to print colored output
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $2"
    else
        echo -e "${RED}✗${NC} $2"
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${GREEN}ℹ${NC} $1"
}

# Check if namespace exists
echo "1. Checking namespace..."
if kubectl get namespace $NAMESPACE &> /dev/null; then
    print_status 0 "Namespace '$NAMESPACE' exists"
else
    print_status 1 "Namespace '$NAMESPACE' does not exist"
    print_warning "Creating namespace..."
    kubectl create namespace $NAMESPACE
fi
echo ""

# Check Multus installation
echo "2. Checking Multus CNI installation..."
MULTUS_PODS=$(kubectl get pods -n kube-system -l app=multus -o name 2>/dev/null | wc -l)
if [ $MULTUS_PODS -gt 0 ]; then
    print_status 0 "Multus CNI is installed ($MULTUS_PODS pods)"
    kubectl get pods -n kube-system -l app=multus
else
    print_status 1 "Multus CNI is not installed"
    print_warning "Install Multus using: kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml"
fi
echo ""

# Check NetworkAttachmentDefinition CRD
echo "3. Checking NetworkAttachmentDefinition CRD..."
if kubectl get crd network-attachment-definitions.k8s.cni.cncf.io &> /dev/null; then
    print_status 0 "NetworkAttachmentDefinition CRD exists"
else
    print_status 1 "NetworkAttachmentDefinition CRD does not exist"
fi
echo ""

# List existing NADs
echo "4. Listing existing NetworkAttachmentDefinitions in namespace '$NAMESPACE'..."
NAD_COUNT=$(kubectl get network-attachment-definitions -n $NAMESPACE --no-headers 2>/dev/null | wc -l)
if [ $NAD_COUNT -gt 0 ]; then
    print_status 0 "Found $NAD_COUNT NAD(s)"
    kubectl get network-attachment-definitions -n $NAMESPACE
else
    print_warning "No NADs found in namespace '$NAMESPACE'"
fi
echo ""

# Check CNI plugins
echo "5. Checking CNI plugins on nodes..."
NODES=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}')
for NODE in $NODES; do
    echo "  Checking node: $NODE"
    kubectl debug node/$NODE -it --image=busybox -- ls /host/opt/cni/bin/ 2>/dev/null || \
        print_warning "Could not check CNI plugins on $NODE"
done
echo ""

# Check for SR-IOV support (if applicable)
echo "6. Checking SR-IOV support..."
SRIOV_NODES=$(kubectl get nodes -l feature.node.kubernetes.io/network-sriov.capable=true --no-headers 2>/dev/null | wc -l)
if [ $SRIOV_NODES -gt 0 ]; then
    print_status 0 "Found $SRIOV_NODES node(s) with SR-IOV capability"
    kubectl get nodes -l feature.node.kubernetes.io/network-sriov.capable=true
else
    print_info "No nodes labeled with SR-IOV capability"
    print_info "To enable SR-IOV, label nodes: kubectl label node <node-name> feature.node.kubernetes.io/network-sriov.capable=true"
fi
echo ""

# Verify NAD details
echo "7. Verifying NAD configurations..."
NADS=$(kubectl get network-attachment-definitions -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')
for NAD in $NADS; do
    echo "  NAD: $NAD"
    CONFIG=$(kubectl get network-attachment-definition $NAD -n $NAMESPACE -o jsonpath='{.spec.config}')
    echo "    Type: $(echo $CONFIG | jq -r '.type')"
    echo "    Master: $(echo $CONFIG | jq -r '.master // "N/A"')"
    echo "    IPAM Type: $(echo $CONFIG | jq -r '.ipam.type')"
    echo ""
done

# Check if UPF pods exist and their network status
echo "8. Checking UPF pod network status..."
UPF_PODS=$(kubectl get pods -n $NAMESPACE -l app=upf -o name 2>/dev/null)
if [ -n "$UPF_PODS" ]; then
    for POD in $UPF_PODS; do
        echo "  Pod: $POD"
        echo "    Network Status:"
        kubectl get $POD -n $NAMESPACE -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' | jq . || \
            print_warning "No network status annotation found"
        
        echo "    Interfaces:"
        kubectl exec -n $NAMESPACE $POD -c bessd -- ip addr 2>/dev/null || \
            print_warning "Could not get interfaces (pod may not be running)"
        echo ""
    done
else
    print_info "No UPF pods found in namespace '$NAMESPACE'"
fi
echo ""

# Test connectivity (if UPF pods exist)
echo "9. Testing network connectivity from UPF pods..."
if [ -n "$UPF_PODS" ]; then
    for POD in $UPF_PODS; do
        POD_NAME=$(echo $POD | cut -d'/' -f2)
        echo "  Testing from pod: $POD_NAME"
        
        # Get interfaces
        INTERFACES=$(kubectl exec -n $NAMESPACE $POD_NAME -c bessd -- ip addr 2>/dev/null | grep -E '^[0-9]+:' | awk '{print $2}' | tr -d ':')
        
        for IFACE in $INTERFACES; do
            if [ "$IFACE" != "lo" ]; then
                IP=$(kubectl exec -n $NAMESPACE $POD_NAME -c bessd -- ip addr show $IFACE 2>/dev/null | grep -oP 'inet \K[\d.]+' | head -1)
                if [ -n "$IP" ]; then
                    echo "    Interface $IFACE has IP: $IP"
                    
                    # Try to get gateway
                    GW=$(kubectl exec -n $NAMESPACE $POD_NAME -c bessd -- ip route 2>/dev/null | grep "dev $IFACE" | grep -oP 'via \K[\d.]+' | head -1)
                    if [ -n "$GW" ]; then
                        echo "      Gateway: $GW"
                        kubectl exec -n $NAMESPACE $POD_NAME -c bessd -- ping -c 2 -W 2 $GW &>/dev/null
                        print_status $? "Ping to gateway $GW"
                    fi
                fi
            fi
        done
        echo ""
    done
else
    print_info "Skipping connectivity tests (no UPF pods found)"
fi
echo ""

# Summary
echo "========================================"
echo "Verification Summary"
echo "========================================"
echo ""

# Provide recommendations
echo "Recommendations:"
if [ $MULTUS_PODS -eq 0 ]; then
    echo "  1. Install Multus CNI"
fi
if [ $NAD_COUNT -eq 0 ]; then
    echo "  2. Create NetworkAttachmentDefinitions for SD-Core"
fi
if [ -z "$UPF_PODS" ]; then
    echo "  3. Deploy SD-Core UPF with Helm"
fi

echo ""
echo "For more information, see the SD-Core NAD guide."
echo ""

# Save detailed report
REPORT_FILE="nad-verification-report-$(date +%Y%m%d-%H%M%S).txt"
echo "Saving detailed report to: $REPORT_FILE"
{
    echo "SD-Core NAD Verification Report"
    echo "Generated: $(date)"
    echo "Namespace: $NAMESPACE"
    echo ""
    echo "=== NADs ==="
    kubectl get network-attachment-definitions -n $NAMESPACE -o yaml
    echo ""
    echo "=== UPF Pods ==="
    kubectl get pods -n $NAMESPACE -l app=upf -o yaml
} > $REPORT_FILE

echo "Report saved successfully!"
