# Nephio Repository Organization: management-config vs Blueprints

## Your Current Setup - Clarification

You have TWO different types of repositories:

```
1. management-config repo          # Nephio management resources
   ├── clustercontext/
   ├── repositories/
   └── packagevariants/

2. blueprint repo(s)                # Upstream packages/blueprints
   ├── baseline/
   ├── addons/
   └── networks/
```

These serve **completely different purposes**!

## Understanding the Distinction

**Repository Type 1: management-config (Nephio Management)**
- Purpose: Configure Nephio itself
- Contains: ClusterContext, Repository CRs, PackageVariant CRs
- Applied to: Management cluster
- Role: Configuration, not packages
- **Upstream in Porch?: NO** - just applied directly

**Repository Type 2: blueprints (Upstream Packages)**
- Purpose: Reusable package templates
- Contains: Infrastructure packages, Workload packages, Kptfiles
- Applied to: Workload clusters (after specialization)
- Role: Upstream templates
- **Upstream in Porch?: YES** - registered as Repository CR

## What Goes Where - Simple Table

| Resource | Repository | Why |
|----------|------------|-----|
| **ClusterContext** | management-config | ConfigSync setup |
| **Repository (Porch)** | management-config | Register repos |
| **PackageVariant** | management-config | Trigger deployments |
| **WorkloadCluster** | management-config | Cluster definitions |
| **IPPrefix** | management-config | IP pool definitions |
| **Interface** | blueprints | Upstream package content |
| **NetworkInstance** | blueprints | Upstream package content |
| **Kptfile** | blueprints | Package metadata |

## Your management-config Repo - Updated Structure

```
management-config/                          # Your existing repo
│
├── clustercontext/                        # ✅ Keep as is
│   └── edge-cluster-1-rootsync.yaml
│
├── repositories/                          # ✅ Keep as is
│   ├── catalog-blueprints-repo.yaml
│   └── edge-cluster-1-repo.yaml
│
├── packagevariants/                       # ✅ Keep as is
│   ├── oai-gnb-edge1-pv.yaml
│   └── upf-edge1-pv.yaml
│
├── workloadclusters/                      # 📝 ADD THIS
│   ├── edge-cluster-1.yaml               # WorkloadCluster resources
│   └── edge-cluster-2.yaml
│
└── ip-pools/                              # 📝 ADD THIS
    ├── control-pool.yaml                 # IPPrefix resources
    ├── userplane-pool.yaml
    ├── datanetwork-pool.yaml
    └── fronthaul-pool.yaml
```

## Your Blueprint Repo - Reorganize

```
catalog-blueprints/                        # Your blueprint repo
│
├── infrastructure/                        # Infrastructure packages
│   ├── baseline/
│   ├── addons/
│   └── multus/
│
└── workloads/                             # Workload packages
    ├── oai-ran/
    │   └── gnb-monolithic/
    │       ├── interface-n2.yaml
    │       ├── interface-n3.yaml
    │       ├── networkinstance-control.yaml
    │       └── Kptfile
    │
    └── sdcore/
        └── upf/
            ├── interface-n3.yaml
            ├── interface-n6.yaml
            └── Kptfile
```

## Key Answer to Your Question

**When I said "mgmt/management" I meant:**
→ **Add folders to your existing management-config repo**
→ **NOT** create a new repo or treat it as upstream

**Your understanding is 100% correct:**
- management-config does NOT act as upstream in Porch
- It contains direct-apply management resources
- WorkloadCluster and IPPrefix belong here

## Summary

```
management-config repo:
✅ Not an "upstream" repo in Porch terms
✅ Contains Nephio management resources
✅ Applied directly: kubectl apply
✅ Keep: ClusterContext, Repository, PackageVariant
✅ ADD: WorkloadCluster, IPPrefix (in new folders)

blueprint repo:
✅ IS an upstream repo in Porch
✅ Contains reusable package templates
✅ Registered via Repository CR
✅ Contains: Interface, NetworkInstance, Kptfiles
```

The confusion came from my use of "mgmt/" - I meant **folders in your management-config repo**, not a separate management blueprint repo!
