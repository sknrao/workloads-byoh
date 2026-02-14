# Nephio Resource Flow: From Blueprint to NAD

## Complete Visual Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                        MANAGEMENT CLUSTER                                                        │
│                                                                                                                  │
│  ┌────────────────────────────────────┐        ┌────────────────────────────────────┐                         │
│  │      IP POOLS (IPPrefix)           │        │   CLUSTER DEFINITION                │                         │
│  │  ┌──────────────────────────────┐  │        │  ┌──────────────────────────────┐  │                         │
│  │  │ apiVersion: ipam...v1alpha1  │  │        │  │ apiVersion: infra...v1alpha1 │  │                         │
│  │  │ kind: IPPrefix               │  │        │  │ kind: WorkloadCluster        │  │                         │
│  │  │ metadata:                    │  │        │  │ metadata:                    │  │                         │
│  │  │   name: control-pool         │  │        │  │   name: edge-cluster-1       │  │                         │
│  │  │ spec:                        │  │        │  │ spec:                        │  │                         │
│  │  │   prefix: 10.1.2.0/24       │  │        │  │   cnis: [macvlan, sriov]    │  │                         │
│  │  │   networkInstance:           │  │        │  │   masterInterface: ens3      │  │                         │
│  │  │     name: vpc-control        │  │        │  │   networkInterfaces:         │  │                         │
│  │  └──────────────────────────────┘  │        │  │   - name: ens3               │  │                         │
│  │                                     │        │  │     cni: macvlan             │  │                         │
│  │  ┌──────────────────────────────┐  │        │  │   - name: ens4               │  │                         │
│  │  │ kind: IPPrefix               │  │        │  │     cni: sriov               │  │                         │
│  │  │ metadata:                    │  │        │  │     sriovEnabled: true       │  │                         │
│  │  │   name: userplane-pool       │  │        │  └──────────────────────────────┘  │                         │
│  │  │ spec:                        │  │        └────────────────────────────────────┘                         │
│  │  │   prefix: 10.1.3.0/24       │  │                          │                                              │
│  │  │   networkInstance:           │  │                          │ Injected into package                       │
│  │  │     name: vpc-userplane      │  │                          │ by workload-cluster-injector               │
│  │  └──────────────────────────────┘  │                          │                                              │
│  └────────────────────────────────────┘                          │                                              │
│                 │                                                  │                                              │
│                 │ Used by IPAM Controller                         │                                              │
│                 │ to allocate IPs                                 │                                              │
└─────────────────┼──────────────────────────────────────────────────┼──────────────────────────────────────────┘
                  │                                                  │
                  │                                                  ▼
┌─────────────────┼──────────────────────────────────────────────────────────────────────────────────────────────┐
│                 │                          PACKAGE (Blueprint)                                                   │
│                 │                                                                                                │
│  ┌──────────────▼──────────────────┐        ┌────────────────────────────────────┐                            │
│  │  NETWORK INSTANCES              │        │   INTERFACES                        │                            │
│  │  ┌──────────────────────────┐   │        │  ┌──────────────────────────────┐  │                            │
│  │  │ apiVersion: infra...v1a1 │   │        │  │ apiVersion: req...v1alpha1   │  │                            │
│  │  │ kind: NetworkInstance    │   │        │  │ kind: Interface              │  │                            │
│  │  │ metadata:                │   │        │  │ metadata:                    │  │                            │
│  │  │   name: vpc-control      │   │        │  │   name: n2                   │  │                            │
│  │  │ spec:                    │   │        │  │   annotations:               │  │                            │
│  │  │   name: vpc-control      │   │        │  │     config.kubernetes.io/    │  │                            │
│  │  │   interfaces:            │   │        │  │     local-config: "true"     │  │                            │
│  │  │   - kind: interface      │   │        │  │ spec:                        │  │                            │
│  │  │     selector:            │   │        │  │   networkInstance:           │  │                            │
│  │  │       matchLabels:       │   │        │  │     name: vpc-control  ◄─────┼──┼─────┐ Links               │
│  │  │         interface: n2    │   │        │  │   cniType: macvlan           │  │     │ NetworkInstance     │
│  │  └──────────────────────────┘   │        │  └──────────────────────────────┘  │     │                     │
│  │                                  │        │                                     │     │                     │
│  │  ┌──────────────────────────┐   │        │  ┌──────────────────────────────┐  │     │                     │
│  │  │ kind: NetworkInstance    │   │        │  │ kind: Interface              │  │     │                     │
│  │  │ metadata:                │   │        │  │ metadata:                    │  │     │                     │
│  │  │   name: vpc-userplane    │   │        │  │   name: n3                   │  │     │                     │
│  │  │ spec:                    │   │        │  │ spec:                        │  │     │                     │
│  │  │   name: vpc-userplane    │   │        │  │   networkInstance:           │  │     │                     │
│  │  │   interfaces:            │   │        │  │     name: vpc-userplane ◄────┼──┼─────┘                     │
│  │  │   - kind: interface      │   │        │  │   cniType: sriov             │  │                           │
│  │  │     selector:            │   │        │  │   sriovSpec:                 │  │                           │
│  │  │       matchLabels:       │   │        │  │     pfName: ens4             │  │                           │
│  │  │         interface: n3    │   │        │  │     vfIndex: 0               │  │                           │
│  │  └──────────────────────────┘   │        │  └──────────────────────────────┘  │                           │
│  └──────────────────────────────────┘        └────────────────────────────────────┘                           │
│                                                                │                                                │
│                                                                │                                                │
│  ┌────────────────────────────────────────────────────────────▼────────────────────────────────────────────┐  │
│  │                                    KPTFILE (Pipeline Definition)                                         │  │
│  │  ┌────────────────────────────────────────────────────────────────────────────────────────────────┐    │  │
│  │  │ apiVersion: kpt.dev/v1                                                                          │    │  │
│  │  │ kind: Kptfile                                                                                   │    │  │
│  │  │ metadata:                                                                                       │    │  │
│  │  │   name: gnb-blueprint                                                                           │    │  │
│  │  │ info:                                                                                           │    │  │
│  │  │   readinessGates:                                                                              │    │  │
│  │  │   - conditionType: config.injection.WorkloadCluster.workload-cluster                          │    │  │
│  │  │   - conditionType: req.nephio.org.interface.n2                                                │    │  │
│  │  │   - conditionType: req.nephio.org.interface.n3                                                │    │  │
│  │  │   - conditionType: ipam.nephio.org.ipclaim.n2                                                 │    │  │
│  │  │   - conditionType: ipam.nephio.org.ipclaim.n3                                                 │    │  │
│  │  │                                                                                                 │    │  │
│  │  │ pipeline:                                                                                       │    │  │
│  │  │   mutators:                                                                                    │    │  │
│  │  │   - image: docker.io/nephio/interface-fn:v2.0.0    ◄──── KRM Function 1                      │    │  │
│  │  │   - image: docker.io/nephio/nad-fn:v2.0.0          ◄──── KRM Function 2                      │    │  │
│  │  └────────────────────────────────────────────────────────────────────────────────────────────────┘    │  │
│  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                    │
                                                    │ PackageVariant triggers
                                                    │ Package specialization
                                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                    KRM FUNCTION EXECUTION (Porch Pipeline)                                       │
│                                                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │  STEP 1: workload-cluster-injector                                                                      │   │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐     │   │
│  │  │  Reads: PackageVariant.spec.injectors                                                         │     │   │
│  │  │  Fetches: WorkloadCluster CR (edge-cluster-1) from management cluster                        │     │   │
│  │  │  Action: Injects WorkloadCluster resource into package                                       │     │   │
│  │  │  Result: Package now contains WorkloadCluster definition                                     │     │   │
│  │  └──────────────────────────────────────────────────────────────────────────────────────────────┘     │   │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                    ↓                                                             │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │  STEP 2: interface-fn (KRM Function)                                                                    │   │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐     │   │
│  │  │  Reads:                                                                                        │     │   │
│  │  │  ├─ Interface resources (n2, n3)                                                              │     │   │
│  │  │  ├─ NetworkInstance resources (vpc-control, vpc-userplane)                                   │     │   │
│  │  │  └─ WorkloadCluster (injected in step 1)                                                      │     │   │
│  │  │                                                                                                │     │   │
│  │  │  Logic:                                                                                        │     │   │
│  │  │  FOR EACH Interface:                                                                          │     │   │
│  │  │    1. Find matching NetworkInstance (via spec.networkInstance.name)                          │     │   │
│  │  │    2. Create IPClaim resource with same name                                                  │     │   │
│  │  │    3. Set IPClaim.spec.networkInstance from Interface                                         │     │   │
│  │  │    4. Mark Interface condition as True                                                        │     │   │
│  │  │                                                                                                │     │   │
│  │  │  Creates: IPClaim resources                                                                   │     │   │
│  │  │  ┌────────────────────────────────────────────────────────────────────┐                      │     │   │
│  │  │  │ apiVersion: ipam.resource.nephio.org/v1alpha1                       │                      │     │   │
│  │  │  │ kind: IPClaim                                                       │                      │     │   │
│  │  │  │ metadata:                                                           │                      │     │   │
│  │  │  │   name: n2                                                          │                      │     │   │
│  │  │  │   namespace: oai-ran                                                │                      │     │   │
│  │  │  │ spec:                                                               │                      │     │   │
│  │  │  │   kind: network                                                     │                      │     │   │
│  │  │  │   networkInstance:                                                  │                      │     │   │
│  │  │  │     name: vpc-control   ◄─────────────────────────────────────┐    │                      │     │   │
│  │  │  │ status: {}  # Empty, waiting for IPAM                          │    │                      │     │   │
│  │  │  └────────────────────────────────────────────────────────────────┼────┘                      │     │   │
│  │  │                                                                    │                           │     │   │
│  │  │  ┌────────────────────────────────────────────────────────────────┼────┐                      │     │   │
│  │  │  │ kind: IPClaim                                                  │    │                      │     │   │
│  │  │  │ metadata:                                                      │    │                      │     │   │
│  │  │  │   name: n3                                                     │    │                      │     │   │
│  │  │  │ spec:                                                          │    │                      │     │   │
│  │  │  │   networkInstance:                                             │    │                      │     │   │
│  │  │  │     name: vpc-userplane  ◄──────────────────────────────────────┘  │                      │     │   │
│  │  │  │ status: {}  # Empty, waiting for IPAM                               │                      │     │   │
│  │  │  └─────────────────────────────────────────────────────────────────────┘                      │     │   │
│  │  │                                                                                                │     │   │
│  │  │  Updates: Kptfile condition req.nephio.org.interface.n2 = True                               │     │   │
│  │  │  Updates: Kptfile condition req.nephio.org.interface.n3 = True                               │     │   │
│  │  └──────────────────────────────────────────────────────────────────────────────────────────────┘     │   │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                    ↓                                                             │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │  STEP 3: IPAM Controller (Watches IPClaim)                                                              │   │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐     │   │
│  │  │  Watches: IPClaim resources                                                                   │     │   │
│  │  │                                                                                                │     │   │
│  │  │  For IPClaim "n2":                                                                            │     │   │
│  │  │    1. Read spec.networkInstance.name = "vpc-control"                                         │     │   │
│  │  │    2. Find IPPrefix with matching networkInstance.name                                       │     │   │
│  │  │       ├─ Searches: IPPrefix resources in management cluster                                  │     │   │
│  │  │       └─ Finds: control-pool (prefix: 10.1.2.0/24, networkInstance: vpc-control)           │     │   │
│  │  │    3. Allocate next available IP from pool: 10.1.2.20                                       │     │   │
│  │  │    4. Update IPClaim.status:                                                                 │     │   │
│  │  │       ├─ prefix: "10.1.2.20/24"                                                             │     │   │
│  │  │       └─ gateway: "10.1.2.1"                                                                │     │   │
│  │  │                                                                                                │     │   │
│  │  │  For IPClaim "n3":                                                                            │     │   │
│  │  │    1. Read spec.networkInstance.name = "vpc-userplane"                                       │     │   │
│  │  │    2. Find IPPrefix: userplane-pool (prefix: 10.1.3.0/24)                                   │     │   │
│  │  │    3. Allocate IP: 10.1.3.20                                                                 │     │   │
│  │  │    4. Update IPClaim.status:                                                                 │     │   │
│  │  │       ├─ prefix: "10.1.3.20/24"                                                             │     │   │
│  │  │       └─ gateway: "10.1.3.1"                                                                │     │   │
│  │  │                                                                                                │     │   │
│  │  │  Result: IPClaim resources now have allocated IPs in status                                  │     │   │
│  │  │                                                                                                │     │   │
│  │  │  ┌────────────────────────────────────────────────────────────────────┐                      │     │   │
│  │  │  │ kind: IPClaim                                                       │                      │     │   │
│  │  │  │ metadata:                                                           │                      │     │   │
│  │  │  │   name: n2                                                          │                      │     │   │
│  │  │  │ spec:                                                               │                      │     │   │
│  │  │  │   networkInstance:                                                  │                      │     │   │
│  │  │  │     name: vpc-control                                               │                      │     │   │
│  │  │  │ status:                          ◄──── Populated by IPAM           │                      │     │   │
│  │  │  │   prefix: 10.1.2.20/24                                              │                      │     │   │
│  │  │  │   gateway: 10.1.2.1                                                 │                      │     │   │
│  │  │  └────────────────────────────────────────────────────────────────────┘                      │     │   │
│  │  │                                                                                                │     │   │
│  │  │  Updates: Kptfile condition ipam.nephio.org.ipclaim.n2 = True                               │     │   │
│  │  │  Updates: Kptfile condition ipam.nephio.org.ipclaim.n3 = True                               │     │   │
│  │  └──────────────────────────────────────────────────────────────────────────────────────────────┘     │   │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                    ↓                                                             │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │  STEP 4: nad-fn (KRM Function)                                                                          │   │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐     │   │
│  │  │  Reads:                                                                                        │     │   │
│  │  │  ├─ Interface resources (n2, n3)                                                              │     │   │
│  │  │  ├─ IPClaim resources with status populated (n2, n3)                                         │     │   │
│  │  │  └─ WorkloadCluster resource                                                                  │     │   │
│  │  │                                                                                                │     │   │
│  │  │  Logic:                                                                                        │     │   │
│  │  │  FOR EACH Interface:                                                                          │     │   │
│  │  │    1. Find matching IPClaim (same name)                                                       │     │   │
│  │  │    2. Read IPClaim.status (IP address, gateway)                                              │     │   │
│  │  │    3. Read Interface.spec.cniType (macvlan or sriov)                                         │     │   │
│  │  │    4. IF cniType == "macvlan":                                                                │     │   │
│  │  │         a. Read WorkloadCluster.spec.masterInterface (e.g., ens3)                            │     │   │
│  │  │         b. OR find from WorkloadCluster.spec.networkInterfaces                               │     │   │
│  │  │         c. Generate MacVLAN NAD with master field                                             │     │   │
│  │  │       ELSE IF cniType == "sriov":                                                             │     │   │
│  │  │         a. Read Interface.spec.sriovSpec.pfName (e.g., ens4)                                 │     │   │
│  │  │         b. Generate SR-IOV NAD (no master field)                                              │     │   │
│  │  │    5. Set IPAM type = "static" with IP from IPClaim                                          │     │   │
│  │  │    6. Add any VLANs, MTU from Interface spec                                                  │     │   │
│  │  │                                                                                                │     │   │
│  │  │  Creates: NetworkAttachmentDefinition (NAD) resources                                         │     │   │
│  │  │                                                                                                │     │   │
│  │  │  For Interface "n2" (MacVLAN):                                                                │     │   │
│  │  │  ┌────────────────────────────────────────────────────────────────────┐                      │     │   │
│  │  │  │ apiVersion: k8s.cni.cncf.io/v1                                      │                      │     │   │
│  │  │  │ kind: NetworkAttachmentDefinition                                   │                      │     │   │
│  │  │  │ metadata:                                                           │                      │     │   │
│  │  │  │   name: n2                                                          │                      │     │   │
│  │  │  │   namespace: oai-ran                                                │                      │     │   │
│  │  │  │ spec:                                                               │                      │     │   │
│  │  │  │   config: |                                                         │                      │     │   │
│  │  │  │     {                                                               │                      │     │   │
│  │  │  │       "cniVersion": "0.3.1",                                        │                      │     │   │
│  │  │  │       "type": "macvlan",       ◄─── From Interface.spec.cniType    │                      │     │   │
│  │  │  │       "master": "ens3",        ◄─── From WorkloadCluster            │                      │     │   │
│  │  │  │       "mode": "bridge",                                             │                      │     │   │
│  │  │  │       "ipam": {                                                     │                      │     │   │
│  │  │  │         "type": "static",      ◄─── Always static for Nephio       │                      │     │   │
│  │  │  │         "addresses": [                                              │                      │     │   │
│  │  │  │           {                                                         │                      │     │   │
│  │  │  │             "address": "10.1.2.20/24",  ◄─── From IPClaim.status   │                      │     │   │
│  │  │  │             "gateway": "10.1.2.1"       ◄─── From IPClaim.status   │                      │     │   │
│  │  │  │           }                                                         │                      │     │   │
│  │  │  │         ]                                                           │                      │     │   │
│  │  │  │       }                                                             │                      │     │   │
│  │  │  │     }                                                               │                      │     │   │
│  │  │  └────────────────────────────────────────────────────────────────────┘                      │     │   │
│  │  │                                                                                                │     │   │
│  │  │  For Interface "n3" (SR-IOV):                                                                 │     │   │
│  │  │  ┌────────────────────────────────────────────────────────────────────┐                      │     │   │
│  │  │  │ apiVersion: k8s.cni.cncf.io/v1                                      │                      │     │   │
│  │  │  │ kind: NetworkAttachmentDefinition                                   │                      │     │   │
│  │  │  │ metadata:                                                           │                      │     │   │
│  │  │  │   name: n3                                                          │                      │     │   │
│  │  │  │   namespace: oai-ran                                                │                      │     │   │
│  │  │  │ spec:                                                               │                      │     │   │
│  │  │  │   config: |                                                         │                      │     │   │
│  │  │  │     {                                                               │                      │     │   │
│  │  │  │       "cniVersion": "0.3.1",                                        │                      │     │   │
│  │  │  │       "type": "sriov",         ◄─── From Interface.spec.cniType    │                      │     │   │
│  │  │  │       "ipam": {                                                     │                      │     │   │
│  │  │  │         "type": "static",                                           │                      │     │   │
│  │  │  │         "addresses": [                                              │                      │     │   │
│  │  │  │           {                                                         │                      │     │   │
│  │  │  │             "address": "10.1.3.20/24",  ◄─── From IPClaim.status   │                      │     │   │
│  │  │  │             "gateway": "10.1.3.1"                                   │                      │     │   │
│  │  │  │           }                                                         │                      │     │   │
│  │  │  │         ]                                                           │                      │     │   │
│  │  │  │       }                                                             │                      │     │   │
│  │  │  │     }                                                               │                      │     │   │
│  │  │  │     Note: No "master" field - SR-IOV uses device plugin            │                      │     │   │
│  │  │  │           pfName (ens4) from Interface.sriovSpec used by plugin    │                      │     │   │
│  │  │  └────────────────────────────────────────────────────────────────────┘                      │     │   │
│  │  │                                                                                                │     │   │
│  │  │  Result: NAD resources created in package                                                     │     │   │
│  │  └──────────────────────────────────────────────────────────────────────────────────────────────┘     │   │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                                  │
│  Final Package State:                                                                                           │
│  ├─ Interface resources (original)                                                                              │
│  ├─ NetworkInstance resources (original)                                                                        │
│  ├─ WorkloadCluster resource (injected)                                                                         │
│  ├─ IPClaim resources (created by interface-fn, status set by IPAM)                                            │
│  ├─ NAD resources (created by nad-fn)                                                                           │
│  └─ Kptfile with all conditions = True                                                                          │
│                                                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                                                    │
                                                    │ Package approved
                                                    │ ConfigSync deploys
                                                    ▼
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                     WORKLOAD CLUSTER (edge-cluster-1)                                            │
│                                                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │  Deployed Resources (from specialized package):                                                         │   │
│  │                                                                                                          │   │
│  │  ✅ NetworkAttachmentDefinition: n2                                                                     │   │
│  │  ✅ NetworkAttachmentDefinition: n3                                                                     │   │
│  │                                                                                                          │   │
│  │  ❌ Interface resources (have local-config annotation, not deployed)                                   │   │
│  │  ❌ NetworkInstance resources (have local-config annotation, not deployed)                             │   │
│  │  ❌ IPClaim resources (have local-config annotation, not deployed)                                     │   │
│  │  ❌ WorkloadCluster resource (have local-config annotation, not deployed)                              │   │
│  │                                                                                                          │   │
│  │  Note: Resources with "config.kubernetes.io/local-config: true" are for                                │   │
│  │        package processing only and are not applied to the cluster                                      │   │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────┘   │
│                                                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────────────────────────────────────────┐   │
│  │  Pod Creation with NADs:                                                                                │   │
│  │                                                                                                          │   │
│  │  When OAI gNB pod is created:                                                                           │   │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐     │   │
│  │  │  apiVersion: v1                                                                               │     │   │
│  │  │  kind: Pod                                                                                     │     │   │
│  │  │  metadata:                                                                                     │     │   │
│  │  │    name: oai-gnb-0                                                                            │     │   │
│  │  │    annotations:                                                                                │     │   │
│  │  │      k8s.v1.cni.cncf.io/networks: n2, n3   ◄─── References NADs                             │     │   │
│  │  │  spec:                                                                                         │     │   │
│  │  │    containers:                                                                                 │     │   │
│  │  │    - name: gnb                                                                                 │     │   │
│  │  │      image: oai-gnb:latest                                                                     │     │   │
│  │  └──────────────────────────────────────────────────────────────────────────────────────────────┘     │   │
│  │                                                                                                          │   │
│  │  Multus processes annotations:                                                                          │   │
│  │  1. Reads NAD "n2" → Calls MacVLAN CNI → Assigns 10.1.2.20 to net1                                    │   │
│  │  2. Reads NAD "n3" → Calls SR-IOV CNI → Assigns VF with 10.1.3.20 to net2                             │   │
│  │                                                                                                          │   │
│  │  Result:                                                                                                 │   │
│  │  ┌──────────────────────────────────────────────────────────────────────────────────────────────┐     │   │
│  │  │  gNB Pod interfaces:                                                                          │     │   │
│  │  │  ├─ eth0: 10.244.0.20 (Primary Calico)                                                       │     │   │
│  │  │  ├─ net1: 10.1.2.20 (N2 via MacVLAN on ens3)                                                 │     │   │
│  │  │  └─ net2: 10.1.3.20 (N3 via SR-IOV VF on ens4)                                               │     │   │
│  │  └──────────────────────────────────────────────────────────────────────────────────────────────┘     │   │
│  └────────────────────────────────────────────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Resource Flow Summary

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Resource Creation Flow                                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Input Resources (You Create):                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. IPPrefix (Management Cluster)                               │    │
│  │    └─ Defines IP pools for IPAM                               │    │
│  │                                                                 │    │
│  │ 2. WorkloadCluster (Management Cluster)                        │    │
│  │    └─ Defines cluster capabilities and NICs                   │    │
│  │                                                                 │    │
│  │ 3. Interface (In Package)                                      │    │
│  │    └─ Declares network interface requirements                 │    │
│  │                                                                 │    │
│  │ 4. NetworkInstance (In Package)                                │    │
│  │    └─ Groups interfaces logically                             │    │
│  │                                                                 │    │
│  │ 5. Kptfile (In Package)                                        │    │
│  │    └─ Defines KRM function pipeline                           │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                          ↓                                               │
│  Processing (Automatic):                                                 │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. workload-cluster-injector                                   │    │
│  │    └─ Injects WorkloadCluster into package                    │    │
│  │                                                                 │    │
│  │ 2. interface-fn (KRM Function)                                 │    │
│  │    └─ Creates IPClaim for each Interface                      │    │
│  │                                                                 │    │
│  │ 3. IPAM Controller                                             │    │
│  │    └─ Allocates IPs from IPPrefix pools                       │    │
│  │    └─ Updates IPClaim.status                                   │    │
│  │                                                                 │    │
│  │ 4. nad-fn (KRM Function)                                       │    │
│  │    └─ Generates NAD from Interface + IPClaim + WorkloadCluster│    │
│  └────────────────────────────────────────────────────────────────┘    │
│                          ↓                                               │
│  Output Resources (Auto-Generated):                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │ 1. IPClaim (Created, not deployed)                             │    │
│  │    └─ With allocated IP in status                             │    │
│  │                                                                 │    │
│  │ 2. NetworkAttachmentDefinition (Created and deployed)          │    │
│  │    └─ Contains CNI config with static IP                      │    │
│  └────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────┘
```

## Key Resource Relationships

```
IPPrefix.spec.networkInstance.name
              │
              │ Matches
              ▼
NetworkInstance.metadata.name ◄──────┐
              │                       │
              │                       │ References
Interface.spec.networkInstance.name ──┘
              │
              │ interface-fn creates
              ▼
IPClaim.spec.networkInstance.name
              │
              │ IPAM Controller matches
              ▼
IPPrefix.spec.networkInstance.name
              │
              │ Allocates IP
              ▼
IPClaim.status.prefix = "10.1.2.20/24"
              │
              │ nad-fn reads
              ▼
NAD.spec.config.ipam.addresses[0].address = "10.1.2.20/24"
```
