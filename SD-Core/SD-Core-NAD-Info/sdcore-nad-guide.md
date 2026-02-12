# SD-Core NetworkAttachmentDefinition (NAD) Guide

## Overview

SD-Core requires multiple network interfaces for different types of traffic, managed through Multus CNI and NetworkAttachmentDefinitions (NADs). This guide explains the network architecture and how to create compatible NADs for your kubeadm cluster integrated with Nephio.

## Network Architecture

### Required Networks for SD-Core

SD-Core (particularly the UPF component) requires **three additional networks** beyond the default Kubernetes pod network:

1. **ENB/Access Network** - For RAN connectivity (gNB/eNB to Core)
2. **Access Network** - For UPF to RAN interface (N3 in 5G, S1-U in 4G)
3. **Core Network** - For UPF to DN/Internet connectivity (N6 in 5G, SGi in 4G)

### Network Mapping

```
┌─────────────┐
│   gNB/eNB   │
└──────┬──────┘
       │ N2/S1-MME (Control Plane)
       │ N3/S1-U (User Plane - Access)
       │
┌──────┴──────────────────────────────┐
│     SD-Core Kubernetes Cluster      │
│                                      │
│  ┌────────┐         ┌────────┐     │
│  │  AMF/  │◄───────►│  UPF   │     │
│  │  MME   │  PFCP   │        │     │
│  └────────┘         └────┬───┘     │
│                          │          │
│                          │ N6/SGi   │
│                          │ (Core)   │
└──────────────────────────┼──────────┘
                           │
                    ┌──────▼──────┐
                    │  Internet/  │
                    │     DN      │
                    └─────────────┘
```

## Prerequisites

### 1. Install Multus CNI

Multus is required to attach multiple network interfaces to pods. On your kubeadm cluster:

```bash
# Install Multus using the thick plugin architecture
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

# Verify installation
kubectl get pods -n kube-system | grep multus
kubectl get crd | grep network-attachment
```

### 2. Install Required CNI Plugins

```bash
# Install standard CNI plugins (if not already present)
# These should be on each node
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.3.0.tgz

# Verify
ls -la /opt/cni/bin/
```

## Understanding SD-Core Network Requirements

### From the sdcore-helm-charts values.yaml

The UPF configuration expects the following network parameters:

```yaml
config:
  upf:
    # ENB network - subnet for gNB/eNB connectivity
    enb:
      subnet: "192.168.2.0/24"  # Customize to your RAN subnet
    
    # Access network - N3/S1-U interface
    access:
      ipam: static
      cniPlugin: macvlan  # or other plugin (vfioveth for SR-IOV)
      iface: "ens3"       # Your physical interface for RAN
      gateway: "192.168.252.1"
      ip: "192.168.252.3/24"
    
    # Core network - N6/SGi interface  
    core:
      ipam: static
      cniPlugin: macvlan  # or other plugin
      iface: "ens4"       # Your physical interface for DN
      gateway: "192.168.250.1"
      ip: "192.168.250.3/24"
```

## Creating NetworkAttachmentDefinitions

### NAD 1: Access Network (N3/S1-U)

This NAD connects the UPF to the RAN (gNB/eNB).

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: access-net
  namespace: omec  # or your SD-Core namespace
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "ens3",
      "mode": "bridge",
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "192.168.252.3/24",
            "gateway": "192.168.252.1"
          }
        ],
        "routes": [
          {
            "dst": "0.0.0.0/0"
          }
        ]
      }
    }
```

**Important Notes:**
- `master`: Must match your physical interface connected to RAN
- `mode`: "bridge" is typical for macvlan
- IP address should match what's configured in UPF helm values

### NAD 2: Core Network (N6/SGi)

This NAD connects the UPF to the Data Network/Internet.

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: core-net
  namespace: omec
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "ens4",
      "mode": "bridge",
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "192.168.250.3/24",
            "gateway": "192.168.250.1"
          }
        ],
        "routes": [
          {
            "dst": "0.0.0.0/0"
          }
        ]
      }
    }
```

### NAD 3: ENB Network (RAN Subnet)

For routing to the RAN subnet:

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: enb-net
  namespace: omec
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "ens3",
      "mode": "bridge",
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "192.168.2.3/24",
            "gateway": "192.168.2.1"
          }
        ]
      }
    }
```

## Alternative: Using SR-IOV for High Performance

For production deployments requiring high throughput, use SR-IOV instead of macvlan:

### Install SR-IOV CNI and Device Plugin

```bash
# Install SR-IOV Network Device Plugin
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/sriov-network-device-plugin/master/deployments/sriovdp-daemonset.yaml

# Install SR-IOV CNI
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/sriov-cni/master/images/sriov-cni-daemonset.yaml
```

### Configure SR-IOV on Nodes

```bash
# Enable VFs on your physical interface (example: ens3)
echo 2 > /sys/class/net/ens3/device/sriov_numvfs

# Get VF PCI addresses
lspci | grep Virtual
```

### SR-IOV NAD Example

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: access-net-sriov
  namespace: omec
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "sriov",
      "vlan": 100,
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "192.168.252.3/24",
            "gateway": "192.168.252.1"
          }
        ]
      }
    }
```

## Integration with Nephio

### Repository Structure

In your Nephio deployment repos (upstream/downstream), organize NADs as follows:

```
nephio-repos/
├── upstream/
│   └── network-configs/
│       ├── access-nad.yaml
│       ├── core-nad.yaml
│       └── enb-nad.yaml
└── downstream/
    └── cluster-specific/
        ├── cluster-1-access-nad.yaml
        └── cluster-1-core-nad.yaml
```

### Using Kptfile for NAD Management

Create a `Kptfile` to manage NAD configurations:

```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: sdcore-network-configs
upstream:
  type: git
  git:
    repo: https://github.com/your-org/network-configs
    directory: /sdcore
    ref: main
upstreamLock:
  type: git
  git:
    repo: https://github.com/your-org/network-configs
    directory: /sdcore
    ref: main
    commit: abc123
```

### ConfigSync Integration

If using Config Sync with Nephio:

```yaml
# config-sync.yaml
apiVersion: configsync.gke.io/v1beta1
kind: RootSync
metadata:
  name: root-sync
  namespace: config-management-system
spec:
  sourceFormat: unstructured
  git:
    repo: https://github.com/your-org/nephio-configs
    branch: main
    dir: network-configs
    auth: token
    secretRef:
      name: git-creds
```

## Updating SD-Core Helm Values

Once NADs are created, update your SD-Core values file:

```yaml
omec-user-plane:
  enable: true
  config:
    upf:
      # Reference to your NADs
      access:
        resourceName: "access-net"  # Matches NAD metadata.name
        ipam: static
        cniPlugin: macvlan
        iface: "ens3"
        gateway: "192.168.252.1"
        ip: "192.168.252.3/24"
      
      core:
        resourceName: "core-net"
        ipam: static
        cniPlugin: macvlan
        iface: "ens4"
        gateway: "192.168.250.1"
        ip: "192.168.250.3/24"
      
      enb:
        subnet: "192.168.2.0/24"
```

## Verification Steps

### 1. Check NAD Creation

```bash
kubectl get network-attachment-definitions -n omec
kubectl describe network-attachment-definition access-net -n omec
```

### 2. Verify Multus Annotations

When UPF pod is deployed, check its annotations:

```bash
kubectl get pod -n omec -l app=upf -o yaml | grep -A 10 annotations
```

Should see:
```yaml
annotations:
  k8s.v1.cni.cncf.io/networks: |
    [
      {"name": "access-net", "namespace": "omec"},
      {"name": "core-net", "namespace": "omec"}
    ]
```

### 3. Check Pod Interfaces

```bash
# Exec into UPF pod
kubectl exec -it -n omec upf-0 -c bessd -- ip addr

# Should see multiple interfaces:
# eth0 - default K8s network
# net1 - access network
# net2 - core network
```

### 4. Test Connectivity

```bash
# From UPF pod, test access network
kubectl exec -it -n omec upf-0 -c bessd -- ping 192.168.252.1

# Test core network
kubectl exec -it -n omec upf-0 -c bessd -- ping 192.168.250.1
```

## Troubleshooting

### Common Issues

1. **NAD not found error**
   - Ensure NAD is in the same namespace as the pod
   - Check NAD name matches exactly in pod annotations

2. **Interface not created**
   - Verify physical interface exists on node
   - Check Multus logs: `kubectl logs -n kube-system <multus-pod>`

3. **IP assignment failures**
   - For static IPAM, ensure IP is not in use
   - Check subnet/gateway configuration

4. **SR-IOV device not available**
   - Verify VFs are created: `cat /sys/class/net/ens3/device/sriov_numvfs`
   - Check device plugin: `kubectl get pods -n kube-system | grep sriov`

### Debugging Commands

```bash
# Check Multus configuration
kubectl get cm -n kube-system multus-cni-config -o yaml

# View CNI plugin logs
journalctl -u kubelet | grep -i cni

# Check node resources for SR-IOV
kubectl get node <node-name> -o json | jq '.status.allocatable'
```

## Best Practices

1. **Network Isolation**: Use separate VLANs for access and core networks
2. **IP Planning**: Ensure no IP conflicts with existing infrastructure
3. **Naming Convention**: Use descriptive names (e.g., `upf-access-n3`, `upf-core-n6`)
4. **Documentation**: Document IP allocations and interface mappings
5. **Testing**: Test NADs in dev environment before production
6. **Monitoring**: Monitor interface statistics and errors
7. **Version Control**: Keep NAD definitions in Git with Nephio repos

## Example: Complete Deployment Flow

```bash
# 1. Create NADs
kubectl apply -f access-nad.yaml
kubectl apply -f core-nad.yaml
kubectl apply -f enb-nad.yaml

# 2. Verify NADs
kubectl get net-attach-def -n omec

# 3. Deploy SD-Core with custom values
helm install -n omec sdcore-5g \
  -f custom-values.yaml \
  omec/sd-core

# 4. Verify UPF pod
kubectl get pods -n omec | grep upf
kubectl describe pod upf-0 -n omec | grep -A 5 "Network Status"

# 5. Check connectivity
kubectl exec -it -n omec upf-0 -c bessd -- ip route
kubectl exec -it -n omec upf-0 -c bessd -- ping <gateway-ip>
```

## References

- SD-Core Helm Charts: https://github.com/omec-project/sdcore-helm-charts
- Multus CNI: https://github.com/k8snetworkplumbingwg/multus-cni
- SR-IOV Network Device Plugin: https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin
- Aether OnRamp Documentation: https://docs.aetherproject.org/
- Nephio Documentation: https://nephio.org/docs/
