# Nephio Resource Mapping: Physical NICs to Logical Interfaces

## Complete Resource Reference Table

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                            Nephio Resource Flow and Physical NIC Mapping                                         │
├──────────────┬─────────────────────┬──────────────────────┬─────────────────────┬──────────────────────────────┤
│ Resource     │ Where Defined       │ Physical NIC Ref     │ Purpose             │ Example                       │
├──────────────┼─────────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ IPPrefix     │ Management Cluster  │ ❌ NOT referenced    │ IP pool definition  │ prefix: 10.1.3.0/24          │
│              │ (namespace: default)│                      │ Maps to             │ networkInstance:             │
│              │                      │                      │ NetworkInstance     │   name: vpc-userplane        │
│              │                      │                      │                     │                              │
│              │ Optional labels:     │ ✅ CAN add label    │ Documentation only  │ labels:                      │
│              │                      │    (not used by     │ (for human          │   physical-nic: ens4         │
│              │                      │     Nephio)         │  reference)         │   cni-type: sriov            │
├──────────────┼─────────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ Network      │ Package             │ ❌ NOT referenced    │ Logical network     │ name: vpc-userplane          │
│ Instance     │ (with Interface)    │                      │ grouping            │ pools:                       │
│              │                      │                      │ Links Interface     │   - name: n3-pool            │
│              │                      │                      │ to IPPrefix         │     prefixLength: 24         │
│              │                      │                      │                     │                              │
│              │ Optional labels:     │ ✅ CAN add label    │ Documentation only  │ labels:                      │
│              │                      │    (not used by     │                     │   physical-nic: ens4         │
│              │                      │     Nephio)         │                     │                              │
├──────────────┼─────────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ Interface    │ Package             │ ❌ NOT directly      │ Declares need for   │ name: n3                     │
│              │ (Blueprint)         │    referenced        │ network interface   │ networkInstance:             │
│              │                      │                      │                     │   name: vpc-userplane        │
│              │                      │                      │ Specifies CNI type  │ cniType: sriov               │
│              │                      │                      │                     │                              │
│              │ Optional labels:     │ ✅ CAN add label    │ Documentation only  │ labels:                      │
│              │                      │    (not used by     │                     │   physical-nic: ens4         │
│              │                      │     Nephio)         │                     │                              │
│              │                      │                      │                     │                              │
│              │ SR-IOV spec:         │ ⚠️ REFERENCES       │ SR-IOV VF           │ sriovSpec:                   │
│              │                      │    PF name          │ configuration       │   pfName: ens4               │
│              │                      │                      │                     │   vfIndex: 0                 │
├──────────────┼─────────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ IPClaim      │ Auto-created by     │ ❌ NOT referenced    │ Requests IP from    │ name: n3                     │
│              │ interface-fn        │                      │ IPPrefix pool       │ networkInstance:             │
│              │                      │                      │                     │   name: vpc-userplane        │
│              │                      │                      │ Status populated    │ status:                      │
│              │                      │                      │ by IPAM controller  │   prefix: 10.1.3.20/24       │
│              │                      │                      │                     │   gateway: 10.1.3.1          │
├──────────────┼─────────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ NAD          │ Auto-created by     │ ✅ YES - CRITICAL    │ Actual CNI config   │ MacVLAN:                     │
│ (Network     │ nad-fn              │    This is where     │ used by Multus      │   master: "ens3"             │
│ Attachment   │                      │    physical NIC      │                     │                              │
│ Definition)  │                      │    is specified!     │ Contains:           │ SR-IOV:                      │
│              │                      │                      │ - CNI type          │   No master needed           │
│              │                      │                      │ - Physical NIC      │   (uses device plugin)       │
│              │                      │                      │ - IPAM config       │                              │
│              │                      │                      │ - IP from IPClaim   │ ipam:                        │
│              │                      │                      │                     │   type: static               │
│              │                      │                      │                     │   addresses:                 │
│              │                      │                      │                     │     - address: 10.1.3.20/24  │
├──────────────┼─────────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ Workload     │ Management Cluster  │ ✅ YES               │ Provides cluster    │ masterInterface: ens3        │
│ Cluster      │ (namespace: default)│    VERY IMPORTANT    │ context to          │                              │
│              │                      │                      │ specialization      │ networkInterfaces:           │
│              │                      │                      │                     │   - name: ens3               │
│              │                      │    Default for       │ Used by nad-fn to   │     cni: macvlan             │
│              │                      │    MacVLAN           │ generate NADs       │   - name: ens4               │
│              │                      │                      │                     │     cni: sriov               │
│              │                      │    Optional details  │                     │     sriovEnabled: true       │
└──────────────┴─────────────────────┴──────────────────────┴─────────────────────┴──────────────────────────────┘
```

## The Critical Mapping Flow

### Question: How does Nephio know N3 should use ens4 instead of ens3?

**Answer: Through the WorkloadCluster resource + CNI type matching**

```
Step-by-Step Flow:
┌─────────────────────────────────────────────────────────────────────────┐
│ 1. Interface Resource (in package)                                      │
│    ┌──────────────────────────────────────────────────────────┐        │
│    │ apiVersion: req.nephio.org/v1alpha1                       │        │
│    │ kind: Interface                                           │        │
│    │ metadata:                                                 │        │
│    │   name: n3                                                │        │
│    │ spec:                                                     │        │
│    │   networkInstance:                                        │        │
│    │     name: vpc-userplane                                   │        │
│    │   cniType: sriov          ◄─── Key: CNI type specified  │        │
│    │   sriovSpec:                                              │        │
│    │     pfName: ens4          ◄─── Physical NIC specified    │        │
│    │     vfIndex: 0                                            │        │
│    └──────────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 2. WorkloadCluster Resource (injected into package)                     │
│    ┌──────────────────────────────────────────────────────────┐        │
│    │ apiVersion: infra.nephio.org/v1alpha1                    │        │
│    │ kind: WorkloadCluster                                    │        │
│    │ metadata:                                                 │        │
│    │   name: edge-cluster-1                                   │        │
│    │ spec:                                                    │        │
│    │   cnis:                                                   │        │
│    │   - sriov                                                │        │
│    │   - macvlan                                               │        │
│    │   masterInterface: ens3    ◄─── Default for MacVLAN     │        │
│    │   networkInterfaces:                                      │        │
│    │   - name: ens3                                           │        │
│    │     cni: macvlan                                          │        │
│    │   - name: ens4                                           │        │
│    │     cni: sriov             ◄─── Maps SR-IOV to ens4     │        │
│    │     sriovEnabled: true                                    │        │
│    └──────────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 3. nad-fn (KRM function) Processes Both                                 │
│                                                                          │
│    Logic:                                                                │
│    IF Interface.spec.cniType == "sriov":                               │
│       - Use Interface.spec.sriovSpec.pfName (ens4)                     │
│       - Generate SR-IOV NAD                                             │
│       - No "master" field needed                                        │
│                                                                          │
│    IF Interface.spec.cniType == "macvlan":                             │
│       - Use WorkloadCluster.spec.masterInterface (ens3)                │
│       - Generate MacVLAN NAD                                            │
│       - Set "master": "ens3"                                            │
└─────────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────┐
│ 4. Generated NAD (result)                                                │
│                                                                          │
│    For N3 (SR-IOV):                                                     │
│    ┌──────────────────────────────────────────────────────────┐        │
│    │ apiVersion: k8s.cni.cncf.io/v1                           │        │
│    │ kind: NetworkAttachmentDefinition                         │        │
│    │ metadata:                                                 │        │
│    │   name: n3                                                │        │
│    │ spec:                                                     │        │
│    │   config: |                                               │        │
│    │     {                                                     │        │
│    │       "type": "sriov",     ◄─── From Interface.cniType  │        │
│    │       "ipam": {                                           │        │
│    │         "type": "static",                                 │        │
│    │         "addresses": [{                                   │        │
│    │           "address": "10.1.3.20/24"  ◄─── From IPClaim  │        │
│    │         }]                                                │        │
│    │       }                                                   │        │
│    │     }                                                     │        │
│    └──────────────────────────────────────────────────────────┘        │
│                                                                          │
│    For N2 (MacVLAN):                                                    │
│    ┌──────────────────────────────────────────────────────────┐        │
│    │ apiVersion: k8s.cni.cncf.io/v1                           │        │
│    │ kind: NetworkAttachmentDefinition                         │        │
│    │ metadata:                                                 │        │
│    │   name: n2                                                │        │
│    │ spec:                                                     │        │
│    │   config: |                                               │        │
│    │     {                                                     │        │
│    │       "type": "macvlan",                                  │        │
│    │       "master": "ens3",    ◄─── From WorkloadCluster    │        │
│    │       "ipam": {                                           │        │
│    │         "type": "static",                                 │        │
│    │         "addresses": [{                                   │        │
│    │           "address": "10.1.2.20/24"                      │        │
│    │         }]                                                │        │
│    │       }                                                   │        │
│    │     }                                                     │        │
│    └──────────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────────────┘
```

## Physical NIC Mapping Summary Table

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│                        Where Physical NIC Names Appear                                      │
├─────────────────┬──────────────────────┬─────────────────────┬──────────────────────────────┤
│ Resource        │ Physical NIC Field   │ Purpose             │ Who Uses It                  │
├─────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ Interface       │ sriovSpec.pfName     │ SR-IOV only:        │ nad-fn                       │
│ (SR-IOV)        │ Example: "ens4"      │ Specify which PF    │ → Generates NAD              │
│                 │                      │ to use              │                              │
├─────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ Interface       │ ❌ None              │ Relies on           │ nad-fn reads                 │
│ (MacVLAN)       │                      │ WorkloadCluster     │ WorkloadCluster              │
│                 │                      │ masterInterface     │ masterInterface              │
├─────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ Workload        │ masterInterface      │ Default physical    │ nad-fn                       │
│ Cluster         │ Example: "ens3"      │ NIC for MacVLAN     │ → Uses for MacVLAN NADs      │
│                 │                      │                     │                              │
│                 │ networkInterfaces    │ Maps CNI types to   │ nad-fn                       │
│                 │ - name: ens3         │ physical NICs       │ → Decides which NIC for      │
│                 │   cni: macvlan       │                     │    which CNI type            │
│                 │ - name: ens4         │                     │                              │
│                 │   cni: sriov         │                     │                              │
├─────────────────┼──────────────────────┼─────────────────────┼──────────────────────────────┤
│ NAD             │ For MacVLAN:         │ Actual physical NIC │ Multus CNI                   │
│ (Generated)     │ "master": "ens3"     │ Multus uses         │ → Attaches pod interface     │
│                 │                      │                     │                              │
│                 │ For SR-IOV:          │ SR-IOV uses device  │ SR-IOV Device Plugin         │
│                 │ No "master" field    │ plugin (pfName from │ → Allocates VF               │
│                 │                      │ Interface resource) │                              │
└─────────────────┴──────────────────────┴─────────────────────┴──────────────────────────────┘
```

## Complete Example: N3 Interface Mapping

### Your Configuration:

**Interface Resource (in package):**
```yaml
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n3
spec:
  networkInstance:
    name: vpc-userplane
  cniType: sriov           # ← Declares SR-IOV
  sriovSpec:
    pfName: ens4           # ← Specifies ens4
    vfIndex: 0
```

**WorkloadCluster Resource:**
```yaml
apiVersion: infra.nephio.org/v1alpha1
kind: WorkloadCluster
metadata:
  name: edge-cluster-1
spec:
  masterInterface: ens3     # ← Default for MacVLAN
  networkInterfaces:
  - name: ens4
    cni: sriov              # ← Confirms ens4 is SR-IOV capable
```

**IPPrefix Resource:**
```yaml
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: oai-userplane-pool
spec:
  prefix: 10.1.3.0/24
  networkInstance:
    name: vpc-userplane     # ← Links to Interface via name
```

### What nad-fn Does:

1. Reads Interface: "Oh, N3 wants SR-IOV on ens4"
2. Reads WorkloadCluster: "Confirms ens4 is SR-IOV"
3. Reads IPClaim status: "IP is 10.1.3.20/24"
4. Generates NAD with:
   - type: sriov (from Interface.cniType)
   - NO master field (SR-IOV doesn't need it)
   - static IPAM with 10.1.3.20/24

### What SR-IOV Device Plugin Does:

1. Reads NAD annotation on pod
2. Sees pod needs SR-IOV resource
3. Allocates VF from ens4 (based on Interface.sriovSpec.pfName)
4. Assigns VF to pod

## Key Takeaways

```
┌─────────────────────────────────────────────────────────────────────┐
│              Physical NIC Mapping: The Truth                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ ❌ IPPrefix does NOT specify physical NIC                          │
│ ❌ NetworkInstance does NOT specify physical NIC                   │
│ ❌ IPClaim does NOT specify physical NIC                           │
│                                                                      │
│ ✅ Interface (SR-IOV) DOES specify physical NIC (pfName)          │
│ ✅ WorkloadCluster DOES specify:                                   │
│    - Default NIC for MacVLAN (masterInterface)                     │
│    - Mapping of CNI types to NICs (networkInterfaces)              │
│                                                                      │
│ ✅ NAD (generated) contains the final physical NIC:                │
│    - MacVLAN: "master" field                                        │
│    - SR-IOV: Implicit from device plugin config                    │
│                                                                      │
│ The mapping happens during NAD generation by nad-fn!                │
└─────────────────────────────────────────────────────────────────────┘
```

## Practical Implications

### To Use Different Physical NICs:

**For MacVLAN interfaces:**
```yaml
# Change WorkloadCluster.spec.masterInterface
masterInterface: ens5  # Now all MacVLAN use ens5 instead of ens3
```

**For SR-IOV interfaces:**
```yaml
# Change Interface.spec.sriovSpec.pfName
sriovSpec:
  pfName: ens6  # Now this interface uses ens6 VFs
  vfIndex: 0
```

**To override per interface (advanced):**
```yaml
# In WorkloadCluster, specify per-interface mappings
networkInterfaces:
- name: ens3
  cni: macvlan
  interfaces:
  - name: n2    # N2 specifically uses ens3
- name: ens4
  cni: macvlan
  interfaces:
  - name: n6    # N6 specifically uses ens4
```

This is how Nephio knows which physical NIC to use for each interface! The WorkloadCluster + Interface.sriovSpec provide the mapping that nad-fn uses to generate correct NADs.
