# Nephio Blueprint Organization: Best Practices

## Your Current Organization

```
blueprints/
├── baseline/
├── addons/
└── networks/
    ├── multus/
    └── network-config/
        ├── Interface
        ├── IPClaim
        ├── NetworkInstance
        ├── IPPrefix
        └── WorkloadCluster
```

## Analysis of Your Current Structure

### ✅ What's Good:
- Clear separation of concerns (baseline, addons, networks)
- Infrastructure vs application separation

### ⚠️ Issues with Current Structure:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    Problems with Current Org                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│ 1. Mixed Scopes:                                                    │
│    - IPPrefix, WorkloadCluster: Management cluster resources       │
│    - Interface, NetworkInstance: Package/workload resources         │
│    - IPClaim: Auto-generated (shouldn't be in blueprint)           │
│                                                                      │
│ 2. Wrong Location:                                                  │
│    - IPPrefix should be at management cluster level                │
│    - WorkloadCluster should be at management cluster level         │
│    - Interface/NetworkInstance should be in workload packages      │
│                                                                      │
│ 3. IPClaim Shouldn't Be Here:                                      │
│    - IPClaim is auto-created by interface-fn                       │
│    - You never manually create IPClaim                             │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Recommended Blueprint Organization

### Option 1: Nephio Standard Organization

This follows Nephio best practices:

```
repository-structure/
│
├── infrastructure/                    # Infrastructure blueprints
│   ├── cluster-baseline/             # Base K8s setup
│   │   ├── namespace.yaml
│   │   ├── rbac.yaml
│   │   └── Kptfile
│   │
│   ├── addons/                       # Cluster add-ons
│   │   ├── monitoring/
│   │   ├── logging/
│   │   └── Kptfile
│   │
│   └── network-infrastructure/       # Network infrastructure
│       ├── multus/                   # Multus CNI
│       │   ├── daemonset.yaml
│       │   ├── configmap.yaml
│       │   └── Kptfile
│       │
│       └── sriov/                    # SR-IOV (if used)
│           ├── device-plugin.yaml
│           ├── configmap.yaml
│           └── Kptfile
│
├── management/                        # Management cluster resources
│   ├── ip-pools/                     # IP address pools
│   │   ├── control-pool.yaml        # IPPrefix for N2
│   │   ├── userplane-pool.yaml      # IPPrefix for N3
│   │   ├── datanetwork-pool.yaml    # IPPrefix for N6
│   │   └── Kptfile
│   │
│   └── workload-clusters/            # Cluster definitions
│       ├── edge-cluster-1.yaml      # WorkloadCluster
│       ├── edge-cluster-2.yaml
│       └── Kptfile
│
└── workloads/                         # Application blueprints
    ├── oai-ran/                      # OAI RAN workloads
    │   ├── gnb-monolithic/           # gNB blueprint
    │   │   ├── interface-n2.yaml    # Interface resources
    │   │   ├── interface-n3.yaml
    │   │   ├── interface-ru.yaml
    │   │   ├── networkinstance-control.yaml
    │   │   ├── networkinstance-userplane.yaml
    │   │   ├── networkinstance-fronthaul.yaml
    │   │   ├── nfdeployment.yaml    # NFDeployment CR
    │   │   └── Kptfile
    │   │
    │   ├── gnb-split-cu/             # CU-CP blueprint
    │   │   ├── interface-n2.yaml
    │   │   ├── interface-f1c.yaml
    │   │   ├── interface-e1.yaml
    │   │   └── Kptfile
    │   │
    │   └── gnb-split-du/             # DU blueprint
    │       ├── interface-f1.yaml
    │       ├── interface-n3.yaml
    │       ├── interface-ru.yaml
    │       └── Kptfile
    │
    └── sdcore/                       # SD-Core workloads
        └── upf/                      # UPF blueprint
            ├── interface-n3.yaml
            ├── interface-n6.yaml
            ├── interface-n4.yaml
            ├── networkinstance-userplane.yaml
            ├── networkinstance-internet.yaml
            ├── networkinstance-internal.yaml
            └── Kptfile
```

### Option 2: Simplified Organization (For Smaller Deployments)

```
blueprints/
│
├── infra/                            # Infrastructure
│   ├── baseline/
│   ├── addons/
│   ├── multus/
│   └── sriov/
│
├── mgmt/                             # Management cluster configs
│   ├── ip-pools.yaml                # All IPPrefix resources
│   ├── edge-cluster-1.yaml          # WorkloadCluster
│   └── Kptfile
│
└── workloads/                        # Workload blueprints
    ├── gnb/
    │   ├── interfaces.yaml          # All Interface resources
    │   ├── networkinstances.yaml    # All NetworkInstance resources
    │   └── Kptfile
    │
    └── upf/
        ├── interfaces.yaml
        ├── networkinstances.yaml
        └── Kptfile
```

### Option 3: Your Current Structure - Fixed

Keep your structure but reorganize:

```
blueprints/
│
├── baseline/                         # As is
│
├── addons/                           # As is
│
├── networks/
│   ├── multus/                      # As is
│   │
│   └── management/                   # NEW: Management resources
│       ├── ip-pools/
│       │   ├── control-pool.yaml    # IPPrefix
│       │   ├── userplane-pool.yaml
│       │   └── datanetwork-pool.yaml
│       │
│       └── clusters/
│           └── edge-cluster-1.yaml  # WorkloadCluster
│
└── workloads/                        # NEW: Workload-specific
    ├── gnb/
    │   ├── interfaces/
    │   │   ├── n2.yaml              # Interface
    │   │   ├── n3.yaml
    │   │   └── ru.yaml
    │   │
    │   └── networkinstances/
    │       ├── vpc-control.yaml     # NetworkInstance
    │       ├── vpc-userplane.yaml
    │       └── vpc-fronthaul.yaml
    │
    └── upf/
        ├── interfaces/
        │   ├── n3.yaml
        │   ├── n6.yaml
        │   └── n4.yaml
        │
        └── networkinstances/
            ├── vpc-userplane.yaml
            ├── vpc-internet.yaml
            └── vpc-internal.yaml
```

## Resource Classification

### Level 1: Infrastructure (Cluster-Wide)
**Location**: `infrastructure/` or `infra/`

```yaml
Examples:
- Multus DaemonSet
- SR-IOV Device Plugin
- Cluster baseline (namespaces, RBAC)
- Monitoring stack

Applied to: Every cluster
Managed by: Platform team
```

### Level 2: Management Cluster
**Location**: `management/` or `mgmt/`

```yaml
Resources:
- IPPrefix (IP pools)
- WorkloadCluster (cluster definitions)
- Repository registrations

Applied to: Management cluster only
Managed by: Platform team
Scope: Cross-cluster resources
```

### Level 3: Workload Blueprints
**Location**: `workloads/`

```yaml
Resources:
- Interface
- NetworkInstance
- NFDeployment
- NFConfig

Applied to: Specific workload clusters
Managed by: Application team
Scope: Per-workload
```

### Level 4: Auto-Generated (DO NOT BLUEPRINT)
**Never put in blueprints**

```yaml
Resources:
- IPClaim (created by interface-fn)
- NAD (created by nad-fn)
- Actual workload pods

These are generated during package specialization
```

## Detailed Resource Placement

```
┌────────────────────────────────────────────────────────────────────────────┐
│                     Where Each Resource Should Live                         │
├──────────────────┬─────────────────────┬──────────────────────────────────┤
│ Resource         │ Location            │ Reason                            │
├──────────────────┼─────────────────────┼──────────────────────────────────┤
│ IPPrefix         │ mgmt/ip-pools/      │ - Management cluster resource    │
│                  │                     │ - Defines IP pools for IPAM      │
│                  │                     │ - Shared across workloads        │
├──────────────────┼─────────────────────┼──────────────────────────────────┤
│ WorkloadCluster  │ mgmt/clusters/      │ - Management cluster resource    │
│                  │                     │ - Defines cluster capabilities   │
│                  │                     │ - One per physical cluster       │
├──────────────────┼─────────────────────┼──────────────────────────────────┤
│ Interface        │ workloads/<nf>/     │ - Workload-specific              │
│                  │ interfaces/         │ - Declares network requirements  │
│                  │                     │ - Part of workload blueprint     │
├──────────────────┼─────────────────────┼──────────────────────────────────┤
│ NetworkInstance  │ workloads/<nf>/     │ - Workload-specific              │
│                  │ networkinstances/   │ - Logical network grouping       │
│                  │                     │ - Links Interface to IPPrefix    │
├──────────────────┼─────────────────────┼──────────────────────────────────┤
│ IPClaim          │ ❌ NEVER            │ - Auto-generated by interface-fn │
│                  │                     │ - Don't create manually          │
├──────────────────┼─────────────────────┼──────────────────────────────────┤
│ NAD              │ ❌ NEVER            │ - Auto-generated by nad-fn       │
│                  │                     │ - Don't create manually          │
├──────────────────┼─────────────────────┼──────────────────────────────────┤
│ Multus           │ infra/multus/       │ - Infrastructure component       │
│                  │                     │ - Deployed to every cluster      │
├──────────────────┼─────────────────────┼──────────────────────────────────┤
│ SR-IOV Plugin    │ infra/sriov/        │ - Infrastructure component       │
│                  │                     │ - Only on SR-IOV capable clusters│
└──────────────────┴─────────────────────┴──────────────────────────────────┘
```

## Example: Complete OAI gNB Blueprint

### Recommended Structure:

```
workloads/oai-ran/gnb-monolithic/
│
├── Kptfile                           # Package metadata
│
├── interfaces/
│   ├── n2.yaml                      # Interface for N2
│   ├── n3.yaml                      # Interface for N3
│   └── ru.yaml                      # Interface for RU
│
├── networkinstances/
│   ├── vpc-control.yaml             # NetworkInstance for N2
│   ├── vpc-userplane.yaml           # NetworkInstance for N3
│   └── vpc-fronthaul.yaml           # NetworkInstance for RU
│
├── deployment/
│   ├── nfdeployment.yaml            # NFDeployment CR (if applicable)
│   └── nfconfig.yaml                # NFConfig CR (if applicable)
│
└── README.md                         # Documentation
```

**Contents of Kptfile:**
```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: gnb-monolithic-blueprint
info:
  description: OAI gNB Monolithic deployment blueprint
  
  readinessGates:
  - conditionType: config.injection.WorkloadCluster.workload-cluster
  - conditionType: req.nephio.org.interface.n2
  - conditionType: req.nephio.org.interface.n3
  - conditionType: req.nephio.org.interface.ru
  - conditionType: ipam.nephio.org.ipclaim.n2
  - conditionType: ipam.nephio.org.ipclaim.n3
  - conditionType: ipam.nephio.org.ipclaim.ru

pipeline:
  mutators:
  - image: docker.io/nephio/interface-fn:v2.0.0
  - image: docker.io/nephio/nad-fn:v2.0.0
  
  validators:
  - image: gcr.io/kpt-fn/kubeval:v0.3.0
```

## File Naming Conventions

### For Interfaces:
```
✅ Good:
- interface-n2.yaml
- interface-n3.yaml
- n2-interface.yaml
- n2.yaml (if in interfaces/ directory)

❌ Bad:
- interface.yaml (too generic)
- int-n2.yaml (unclear abbreviation)
- n2_interface.yaml (use hyphens, not underscores)
```

### For NetworkInstances:
```
✅ Good:
- networkinstance-control.yaml
- vpc-control.yaml
- ni-control.yaml

❌ Bad:
- network.yaml (too generic)
- networkinstance.yaml (needs descriptor)
```

### For Management Resources:
```
✅ Good:
- control-pool.yaml (IPPrefix)
- edge-cluster-1.yaml (WorkloadCluster)
- userplane-pool.yaml

❌ Bad:
- ipprefix-1.yaml (use descriptive name)
- cluster.yaml (too generic)
```

## Git Repository Structure

### Recommended:

```
nephio-blueprints/                   # Main repo
├── infrastructure/
├── management/
└── workloads/

nephio-deployments/                  # Deployment repo
├── edge-cluster-1/                  # Per-cluster repo
│   ├── oai-gnb-edge1/              # Specialized packages
│   └── upf-edge1/
└── edge-cluster-2/
```

### Alternative: Monorepo

```
nephio/
├── blueprints/                      # Upstream packages
│   ├── infrastructure/
│   ├── management/
│   └── workloads/
│
└── deployments/                     # Downstream packages
    ├── edge-cluster-1/
    └── edge-cluster-2/
```

## Migration Path from Your Current Structure

### Step 1: Create New Structure
```bash
mkdir -p blueprints/mgmt/{ip-pools,clusters}
mkdir -p blueprints/workloads/oai-ran/gnb/{interfaces,networkinstances}
mkdir -p blueprints/workloads/sdcore/upf/{interfaces,networkinstances}
```

### Step 2: Move IPPrefix Resources
```bash
# Move IP pools to management
mv blueprints/networks/network-config/IPPrefix/* \
   blueprints/mgmt/ip-pools/
```

### Step 3: Move WorkloadCluster
```bash
# Move cluster definitions
mv blueprints/networks/network-config/WorkloadCluster/* \
   blueprints/mgmt/clusters/
```

### Step 4: Move Interface Resources
```bash
# Move to workload-specific locations
mv blueprints/networks/network-config/Interface/n2.yaml \
   blueprints/workloads/oai-ran/gnb/interfaces/

mv blueprints/networks/network-config/Interface/n3-gnb.yaml \
   blueprints/workloads/oai-ran/gnb/interfaces/n3.yaml

mv blueprints/networks/network-config/Interface/n3-upf.yaml \
   blueprints/workloads/sdcore/upf/interfaces/n3.yaml
```

### Step 5: Move NetworkInstance Resources
```bash
# Similarly for NetworkInstance
mv blueprints/networks/network-config/NetworkInstance/vpc-control.yaml \
   blueprints/workloads/oai-ran/gnb/networkinstances/
```

### Step 6: Remove IPClaim (if exists)
```bash
# IPClaim should never be in blueprints
rm -rf blueprints/networks/network-config/IPClaim/
```

### Step 7: Clean Up Old Structure
```bash
# Remove empty directories
rm -rf blueprints/networks/network-config/
```

## Summary Table

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Blueprint Organization Summary                        │
├──────────────────┬────────────────────┬─────────────────────────────────┤
│ Directory        │ Contains           │ Applied To                       │
├──────────────────┼────────────────────┼─────────────────────────────────┤
│ infrastructure/  │ Base cluster setup │ Every cluster                   │
├──────────────────┼────────────────────┼─────────────────────────────────┤
│ mgmt/ip-pools/   │ IPPrefix           │ Management cluster              │
├──────────────────┼────────────────────┼─────────────────────────────────┤
│ mgmt/clusters/   │ WorkloadCluster    │ Management cluster              │
├──────────────────┼────────────────────┼─────────────────────────────────┤
│ workloads/       │ Interface          │ Specific workload clusters      │
│                  │ NetworkInstance    │                                 │
│                  │ NFDeployment       │                                 │
└──────────────────┴────────────────────┴─────────────────────────────────┘
```

## Key Takeaways

1. **Separate by Scope**: Infrastructure → Management → Workloads
2. **IPClaim is Auto-Generated**: Never put in blueprints
3. **WorkloadCluster & IPPrefix**: Management cluster resources
4. **Interface & NetworkInstance**: Workload-specific resources
5. **One Blueprint Per Workload**: gnb/, upf/, etc.

Your current organization mixes these scopes. The recommended structure clarifies where each resource belongs and makes it easier to manage and understand the system!
