# SD-Core NAD Quick Reference

## Network Interfaces Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    SD-Core Network Layout                    │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  gNB/eNB ◄──────N2/N3──────► UPF ◄─────N6─────► Internet   │
│  (RAN)      (Access Net)    (Pod)  (Core Net)      (DN)     │
│                                                               │
│  192.168.2.x   192.168.252.x      192.168.250.x              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

## Required NADs

| NAD Name | Interface | Network | Purpose |
|----------|-----------|---------|---------|
| upf-access-n3 | N3 | 192.168.252.0/24 | UPF to RAN (gNB) |
| upf-core-n6 | N6 | 192.168.250.0/24 | UPF to Internet/DN |
| upf-enb-subnet | - | 192.168.2.0/24 | RAN subnet routing |

## Key Parameters to Customize

### In NAD YAML:
- `master`: Physical interface name (e.g., ens3, ens4)
- `address`: IP address for the interface
- `gateway`: Gateway IP for the network
- `vlan`: VLAN ID (if using VLANs)

### In SD-Core Helm values.yaml:
```yaml
config:
  upf:
    access:
      iface: "ens3"              # Match NAD master
      ip: "192.168.252.3/24"     # Match NAD address
      gateway: "192.168.252.1"   # Match NAD gateway
    core:
      iface: "ens4"
      ip: "192.168.250.3/24"
      gateway: "192.168.250.1"
    enb:
      subnet: "192.168.2.0/24"
```

## CNI Plugin Options

### MacVLAN (Standard)
- **Use when**: General purpose, moderate performance
- **Pros**: Easy setup, widely supported
- **Cons**: Lower performance than SR-IOV
- **Mode**: bridge (most common)

### SR-IOV (High Performance)
- **Use when**: High throughput required (>10Gbps)
- **Pros**: Hardware acceleration, near line-rate
- **Cons**: Requires SR-IOV capable NIC, complex setup
- **Device Type**: netdevice or vfio (for DPDK)

### IPVLAN
- **Use when**: Need L3 routing, no L2 broadcast
- **Pros**: Better isolation than MacVLAN
- **Cons**: Less tested with SD-Core

## Common Commands

### Create NADs
```bash
kubectl apply -f nad-templates-macvlan.yaml
```

### Verify NADs
```bash
kubectl get network-attachment-definitions -n omec
kubectl describe network-attachment-definition upf-access-n3 -n omec
```

### Check pod interfaces
```bash
kubectl get pod upf-0 -n omec -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' | jq .
kubectl exec -it -n omec upf-0 -c bessd -- ip addr
```

### Test connectivity
```bash
# Ping access gateway
kubectl exec -it -n omec upf-0 -c bessd -- ping 192.168.252.1

# Ping core gateway  
kubectl exec -it -n omec upf-0 -c bessd -- ping 192.168.250.1

# Check routes
kubectl exec -it -n omec upf-0 -c bessd -- ip route
```

## Troubleshooting Quick Fixes

### Issue: "network not found"
```bash
# Check NAD exists in correct namespace
kubectl get net-attach-def -n omec
```

### Issue: "interface not created"
```bash
# Check Multus logs
kubectl logs -n kube-system -l app=multus

# Verify physical interface on node
kubectl get nodes
kubectl debug node/<node-name> -it --image=busybox -- ip link show
```

### Issue: "IP assignment failed"
```bash
# Check if IP is already in use
kubectl exec -it -n omec upf-0 -c bessd -- ip addr

# Verify IPAM configuration in NAD
kubectl get net-attach-def upf-access-n3 -n omec -o yaml
```

### Issue: "no connectivity"
```bash
# Check routes
kubectl exec -it -n omec upf-0 -c bessd -- ip route

# Verify gateway is reachable from host
ping 192.168.252.1

# Check firewall/iptables on host
sudo iptables -L -v -n
```

## Integration with Nephio

### Directory Structure
```
nephio-repos/
├── upstream/
│   └── sdcore-network/
│       ├── nad-access.yaml
│       ├── nad-core.yaml
│       └── Kptfile
└── downstream/
    └── site-xyz/
        ├── nad-access-customized.yaml
        └── Kptfile
```

### Using kpt to manage NADs
```bash
# Get package from upstream
kpt pkg get https://github.com/your-org/nephio-packages/sdcore-network sdcore-network

# Customize for your site
cd sdcore-network
vi nad-access.yaml  # Edit IPs, interfaces

# Apply to cluster
kpt live init
kpt live apply
```

## Network Planning Template

| Item | Value | Notes |
|------|-------|-------|
| **Access Network** | | |
| Physical Interface | ens3 | |
| Subnet | 192.168.252.0/24 | |
| UPF IP | 192.168.252.3 | |
| Gateway | 192.168.252.1 | |
| VLAN (if any) | 100 | |
| **Core Network** | | |
| Physical Interface | ens4 | |
| Subnet | 192.168.250.0/24 | |
| UPF IP | 192.168.250.3 | |
| Gateway | 192.168.250.1 | |
| VLAN (if any) | 200 | |
| **RAN Subnet** | | |
| Subnet | 192.168.2.0/24 | |
| gNB IP Range | 192.168.2.10-100 | |

## Pre-Deployment Checklist

- [ ] Multus CNI installed
- [ ] Network interfaces identified (ens3, ens4, etc.)
- [ ] IP addressing planned (no conflicts)
- [ ] VLANs configured (if applicable)
- [ ] SR-IOV enabled (if using SR-IOV)
- [ ] NAD YAMLs customized with correct IPs/interfaces
- [ ] Namespace created (omec or custom)
- [ ] NADs created and verified
- [ ] SD-Core Helm values updated to reference NADs
- [ ] Physical network connectivity verified

## Post-Deployment Verification

- [ ] NADs exist in namespace: `kubectl get net-attach-def -n omec`
- [ ] UPF pod has multiple interfaces: `kubectl exec upf-0 -n omec -- ip addr`
- [ ] Interfaces have correct IPs
- [ ] Can ping access gateway from UPF
- [ ] Can ping core gateway from UPF
- [ ] Routes are correct: `kubectl exec upf-0 -n omec -- ip route`
- [ ] gNB can connect to UPF
- [ ] UPF can reach Internet/DN

## Useful Links

- SD-Core Docs: https://docs.sd-core.aetherproject.org/
- Multus CNI: https://github.com/k8snetworkplumbingwg/multus-cni
- SR-IOV Guide: https://github.com/k8snetworkplumbingwg/sriov-network-device-plugin
- Nephio: https://nephio.org/
- Aether OnRamp: https://docs.aetherproject.org/master/onramp/overview.html
