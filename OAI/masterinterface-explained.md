# Understanding masterInterface and Multi-NIC MacVLAN Mapping

## What is masterInterface?

### Definition

`masterInterface` in WorkloadCluster is simply the **DEFAULT** physical NIC that MacVLAN interfaces will use **IF** you don't specify otherwise.

```yaml
apiVersion: infra.nephio.org/v1alpha1
kind: WorkloadCluster
spec:
  masterInterface: ens3  # ← This is just the DEFAULT, not mandatory for all
```

### Important Clarifications

```
┌─────────────────────────────────────────────────────────────────────┐
│              masterInterface Misconceptions                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ ❌ MYTH: masterInterface must be the cluster's management interface │
│ ✅ TRUTH: Can be ANY physical interface on the node                │
│                                                                      │
│ ❌ MYTH: masterInterface must be the interface used during install  │
│ ✅ TRUTH: Has nothing to do with K8s installation interface        │
│                                                                      │
│ ❌ MYTH: All MacVLAN interfaces MUST use masterInterface           │
│ ✅ TRUTH: You can override per-interface using networkInterfaces   │
│                                                                      │
│ ❌ MYTH: masterInterface must have an IP address                    │
│ ✅ TRUTH: Can be a bare interface without IP (L2 only)             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Kubernetes Management Interface vs masterInterface

### Your Cluster Setup

```
When you installed Kubernetes:
┌────────────────────────────────────────────────────────────┐
│ Node IP: 192.168.1.100                                     │
│ Interface: ens3                                            │
│ Purpose: K8s API, kubelet, CNI (Calico/Flannel)          │
│                                                            │
│ This is the "management" interface for K8s                │
└────────────────────────────────────────────────────────────┘

For Multus + MacVLAN:
┌────────────────────────────────────────────────────────────┐
│ masterInterface: Can be ens3, ens4, ens5, or ANY interface│
│ Purpose: For secondary networks (N2, N4, N6, etc.)        │
│                                                            │
│ DOES NOT need to be the same as K8s management interface │
└────────────────────────────────────────────────────────────┘
```

### Example Scenarios

#### Scenario 1: Same as Management Interface
```yaml
# K8s installed with ens3 IP: 192.168.1.100
# You want secondary networks also on ens3

WorkloadCluster:
  masterInterface: ens3  # ✅ ALLOWED - Can be same as management
```

**This works because:**
- MacVLAN creates virtual interfaces on top of ens3
- They have different MAC addresses
- They operate at Layer 2, don't conflict with K8s management IP

#### Scenario 2: Different from Management Interface
```yaml
# K8s installed with ens3 IP: 192.168.1.100
# You want secondary networks on ens4 (dedicated)

WorkloadCluster:
  masterInterface: ens4  # ✅ ALLOWED - Can be different
```

**This is actually BETTER because:**
- Separates management traffic from application traffic
- No contention between K8s and secondary networks
- Cleaner architecture

#### Scenario 3: Bare Interface (No IP)
```yaml
# K8s installed with ens3 IP: 192.168.1.100
# ens4 has NO IP address assigned

WorkloadCluster:
  masterInterface: ens4  # ✅ ALLOWED - Interface can be bare
```

**This works because:**
- MacVLAN only needs the interface to be UP
- Doesn't need IP on the master interface
- Each MacVLAN sub-interface gets its own IP

## How to Map Different Interfaces to Different Physical NICs

### Your Question: Can N2, N4 use ens3 and N6 use ens6?

**Answer: YES! Absolutely!**

### Method 1: Using networkInterfaces in WorkloadCluster

```yaml
apiVersion: infra.nephio.org/v1alpha1
kind: WorkloadCluster
metadata:
  name: edge-cluster-1
spec:
  cnis:
  - macvlan
  - sriov
  
  # Default fallback (optional if you specify everything below)
  masterInterface: ens3
  
  # Detailed mapping: which interface uses which physical NIC
  networkInterfaces:
  
  # ens3: For N2 and N4
  - name: ens3
    purpose: control-and-pfcp
    cni: macvlan
    interfaces:
    - name: n2        # ← N2 uses ens3
      purpose: "Control plane to AMF"
    - name: n4        # ← N4 uses ens3
      purpose: "PFCP to SMF"
  
  # ens4: For N3 (SR-IOV)
  - name: ens4
    purpose: userplane
    cni: sriov
    sriovEnabled: true
    interfaces:
    - name: n3        # ← N3 uses ens4 (SR-IOV)
      purpose: "User plane"
  
  # ens6: For N6
  - name: ens6
    purpose: data-network
    cni: macvlan
    interfaces:
    - name: n6        # ← N6 uses ens6
      purpose: "Data network/Internet"
```

### Method 2: Specify in Interface Resource (More Explicit)

Unfortunately, the standard Nephio Interface resource doesn't have a `masterInterface` field for MacVLAN (only `pfName` for SR-IOV). 

**But you can work around this:**

```yaml
# For N2 on ens3
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n2
  annotations:
    nephio.org/master-interface: ens3  # Custom annotation (if nad-fn supports)
spec:
  networkInstance:
    name: vpc-control
  cniType: macvlan

---
# For N6 on ens6
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n6
  annotations:
    nephio.org/master-interface: ens6  # Custom annotation
spec:
  networkInstance:
    name: vpc-internet
  cniType: macvlan
```

**However**, the standard nad-fn might not read this annotation. You'd need to check Nephio's implementation or use Method 1.

### Method 3: Create Separate WorkloadCluster Contexts (Not Recommended)

You could create multiple WorkloadCluster resources, but this is overly complex.

## Complete Example: Your Desired Setup

### Your Requirements:
- **N2** → ens3 (MacVLAN)
- **N3** → ens4 (SR-IOV)
- **N4** → ens3 (MacVLAN)
- **N6** → ens6 (MacVLAN)
- **RU** → ens5 (MacVLAN)

### Solution: Updated WorkloadCluster

```yaml
apiVersion: infra.nephio.org/v1alpha1
kind: WorkloadCluster
metadata:
  name: edge-cluster-1
  namespace: default
spec:
  clusterName: edge-cluster-1
  
  cnis:
  - macvlan
  - sriov
  
  # Default for any MacVLAN not explicitly specified
  masterInterface: ens3
  
  # Detailed per-interface mapping
  networkInterfaces:
  
  # ens3: Control plane interfaces
  - name: ens3
    purpose: control-and-management
    description: "For N2 (control) and N4 (PFCP)"
    cni: macvlan
    speed: 10G
    vlans:
    - 102  # N2 VLAN
    - 104  # N4 VLAN
    interfaces:
    - name: n2
      vlan: 102
      purpose: "NGAP to AMF"
    - name: n4
      vlan: 104
      purpose: "PFCP to SMF"
  
  # ens4: High-performance user plane
  - name: ens4
    purpose: userplane
    description: "For N3 via SR-IOV"
    cni: sriov
    sriovEnabled: true
    speed: 25G
    interfaces:
    - name: n3
      purpose: "GTP-U user plane"
      vfCount: 4
      vfDriver: iavf
  
  # ens5: Fronthaul to USRP
  - name: ens5
    purpose: fronthaul
    description: "For RU to USRP"
    cni: macvlan
    speed: 1G
    mtu: 9000
    interfaces:
    - name: ru
      purpose: "Fronthaul to radio unit"
  
  # ens6: Data network
  - name: ens6
    purpose: data-network
    description: "For N6 to Internet/DN"
    cni: macvlan
    speed: 10G
    vlans:
    - 106  # N6 VLAN
    interfaces:
    - name: n6
      vlan: 106
      purpose: "Data network egress"
  
  # SR-IOV configuration
  sriovConfig:
    enabled: true
    devices:
    - physicalFunction: ens4
      numVirtualFunctions: 4
      vfDriver: iavf
      pfDriver: ice
```

## How nad-fn Uses This

### For N2 (MacVLAN on ens3)

```
1. nad-fn reads Interface "n2"
   - cniType: macvlan
   
2. nad-fn reads WorkloadCluster
   - Finds: networkInterfaces[0].interfaces contains "n2"
   - networkInterfaces[0].name = "ens3"
   
3. nad-fn generates NAD:
   {
     "type": "macvlan",
     "master": "ens3",    ← From WorkloadCluster mapping
     "vlan": 102,
     "ipam": {...}
   }
```

### For N6 (MacVLAN on ens6)

```
1. nad-fn reads Interface "n6"
   - cniType: macvlan
   
2. nad-fn reads WorkloadCluster
   - Finds: networkInterfaces[3].interfaces contains "n6"
   - networkInterfaces[3].name = "ens6"
   
3. nad-fn generates NAD:
   {
     "type": "macvlan",
     "master": "ens6",    ← From WorkloadCluster mapping
     "vlan": 106,
     "ipam": {...}
   }
```

### For N3 (SR-IOV on ens4)

```
1. nad-fn reads Interface "n3"
   - cniType: sriov
   - sriovSpec.pfName: ens4
   
2. nad-fn generates NAD:
   {
     "type": "sriov",     ← No "master" field needed
     "ipam": {...}
   }
   
3. SR-IOV device plugin uses pfName from Interface
```

## Verification After Deployment

```bash
# Check generated NADs
kubectl get network-attachment-definitions -n oai-ran -o yaml

# For N2 - should show:
# "master": "ens3"

# For N6 - should show:
# "master": "ens6"

# For N3 - should show:
# "type": "sriov" (no master field)
```

## Physical NIC Requirements

### What each NIC needs:

```
ens3 (K8s management + N2 + N4):
├─ State: UP
├─ IP: 192.168.1.100 (for K8s) - OK to have
├─ Promisc: ON (for MacVLAN)
└─ Can handle: K8s traffic + N2 + N4 (low bandwidth)

ens4 (N3 SR-IOV):
├─ State: UP
├─ IP: Not needed (can be bare)
├─ SR-IOV: Enabled in BIOS + kernel
├─ VFs: Created (4 VFs)
└─ Driver: ice (PF), iavf (VF)

ens5 (RU):
├─ State: UP
├─ IP: Not needed (can be bare)
├─ MTU: 9000 (jumbo frames)
├─ Promisc: ON (for MacVLAN)
└─ Connected to: USRP

ens6 (N6):
├─ State: UP
├─ IP: Not needed (can be bare)
├─ Promisc: ON (for MacVLAN)
├─ Connected to: Router/Internet gateway
└─ Can be same as ens3 if you don't have separate NIC
```

## Common Scenarios

### Scenario 1: Limited NICs (only ens3 and ens4)

```yaml
# Use ens3 for N2, N4, N6 (all MacVLAN)
# Use ens4 for N3 (SR-IOV)
# Skip RU (RF simulator mode)

WorkloadCluster:
  masterInterface: ens3
  networkInterfaces:
  - name: ens3
    cni: macvlan
    interfaces:
    - name: n2
    - name: n4
    - name: n6
  - name: ens4
    cni: sriov
    interfaces:
    - name: n3
```

### Scenario 2: Many NICs (ens3, ens4, ens5, ens6)

```yaml
# Spread across multiple NICs for better isolation
# ens3: N2, N4 (control plane)
# ens4: N3 (SR-IOV user plane)
# ens5: RU (fronthaul)
# ens6: N6 (data network)

WorkloadCluster:
  masterInterface: ens3
  networkInterfaces:
  - name: ens3
    cni: macvlan
    interfaces: [n2, n4]
  - name: ens4
    cni: sriov
    interfaces: [n3]
  - name: ens5
    cni: macvlan
    interfaces: [ru]
  - name: ens6
    cni: macvlan
    interfaces: [n6]
```

### Scenario 3: ens3 is K8s Management, Keep It Separate

```yaml
# Don't use ens3 for any secondary networks
# Use only ens4, ens5, ens6 for Multus

WorkloadCluster:
  masterInterface: ens4  # Default to ens4 (not ens3)
  networkInterfaces:
  - name: ens4
    cni: macvlan
    interfaces: [n2, n4]  # Control on ens4
  - name: ens5
    cni: sriov
    interfaces: [n3]      # User plane on ens5
  - name: ens6
    cni: macvlan
    interfaces: [n6]      # Data on ens6
  
  # ens3 not listed - reserved for K8s management
```

## Summary

```
┌─────────────────────────────────────────────────────────────────┐
│                  masterInterface Clarified                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│ ✅ masterInterface is just a DEFAULT                           │
│    - Used when no explicit mapping exists                      │
│                                                                  │
│ ✅ Can be same as K8s management interface                     │
│    - MacVLAN creates virtual interfaces, no conflict           │
│                                                                  │
│ ✅ Can be different from K8s management interface              │
│    - Actually preferred for separation                          │
│                                                                  │
│ ✅ Can override per-interface using networkInterfaces          │
│    - N2, N4 on ens3                                            │
│    - N6 on ens6                                                │
│    - N3 on ens4 (SR-IOV)                                       │
│                                                                  │
│ ✅ Interface doesn't need an IP address                        │
│    - Can be a bare L2 interface                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Answer to your specific question:**
- ✅ YES, you can associate N2+N4 to ens3 and N6 to ens6
- ✅ Use the `networkInterfaces` section in WorkloadCluster
- ✅ Each logical interface (N2, N4, N6) can map to different physical NICs
