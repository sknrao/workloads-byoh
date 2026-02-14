# Complete PackageVariant Examples with Correct References

## Your Understanding is 100% Correct!

```yaml
upstream:
  repo: nephio-blueprints              # ✅ Your blueprint repo name
  package: infrastructure/baseline      # ✅ Path within repo
  revision: main                        # ✅ Git branch

upstream:
  repo: nephio-blueprints
  package: infrastructure/multus
  revision: main

upstream:
  repo: nephio-blueprints
  package: infrastructure/addons
  revision: main

upstream:
  repo: nephio-blueprints
  package: workloads/oai-ran/gnb
  revision: main
```

## Complete PackageVariant Files

### Repository Registration (in management-config repo)

**File: management-config/repositories/nephio-blueprints-repo.yaml**

```yaml
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: nephio-blueprints
  namespace: default
spec:
  description: "My Nephio blueprints repository"
  type: git
  content: Package        # Important: This makes it an upstream repo
  deployment: false       # Not a deployment target
  git:
    repo: https://github.com/YOUR_ORG/nephio-blueprints.git
    branch: main
    directory: /          # Root of repo
    # secretRef:          # Optional, if private repo
    #   name: git-credentials
```

**Apply this first:**
```bash
kubectl apply -f management-config/repositories/nephio-blueprints-repo.yaml

# Verify
kubectl get repositories
# Should show: nephio-blueprints
```

### PackageVariant for Infrastructure

**File: management-config/packagevariants/baseline-pv.yaml**

```yaml
---
# PackageVariant for baseline
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: baseline-edge1
  namespace: default
  labels:
    nephio.org/package-type: infrastructure
spec:
  upstream:
    repo: nephio-blueprints           # ✅ Matches Repository name
    package: infrastructure/baseline   # ✅ Path in repo
    revision: main                     # ✅ Git branch/tag
  
  downstream:
    repo: edge-cluster-1              # Your edge cluster repo
    package: baseline-edge1           # Package name in downstream
  
  adoptionPolicy: adoptExisting
  deletionPolicy: delete

---
# PackageVariant for multus
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: multus-edge1
  namespace: default
  labels:
    nephio.org/package-type: infrastructure
spec:
  upstream:
    repo: nephio-blueprints
    package: infrastructure/multus
    revision: main
  
  downstream:
    repo: edge-cluster-1
    package: multus-edge1

---
# PackageVariant for addons
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: addons-edge1
  namespace: default
  labels:
    nephio.org/package-type: infrastructure
spec:
  upstream:
    repo: nephio-blueprints
    package: infrastructure/addons
    revision: main
  
  downstream:
    repo: edge-cluster-1
    package: addons-edge1
```

### PackageVariant for Workloads

**File: management-config/packagevariants/oai-gnb-pv.yaml**

```yaml
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: oai-gnb-edge1
  namespace: default
  labels:
    nephio.org/package-type: workload
    nephio.org/network-function: gnb
spec:
  upstream:
    repo: nephio-blueprints            # ✅ Your blueprint repo
    package: workloads/oai-ran/gnb     # ✅ Path to gNB package
    revision: main
  
  downstream:
    repo: edge-cluster-1               # Deployment target
    package: oai-gnb-edge1             # Specialized package name
  
  # Inject WorkloadCluster for specialization
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-cluster-1       # From management-config/workloadclusters/
  
  adoptionPolicy: adoptExisting
  deletionPolicy: delete
  
  # Optional: Apply mutations
  pipeline:
    mutators:
    # Set site labels
    - image: gcr.io/kpt-fn/set-labels:v0.2
      configMap:
        nephio.org/site: edge-cluster-1
        nephio.org/region: us-west
```

### PackageVariant for UPF

**File: management-config/packagevariants/upf-pv.yaml**

```yaml
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: upf-edge1
  namespace: default
  labels:
    nephio.org/package-type: workload
    nephio.org/network-function: upf
spec:
  upstream:
    repo: nephio-blueprints             # ✅ Your blueprint repo
    package: workloads/sdcore/upf       # ✅ Path to UPF package
    revision: main
  
  downstream:
    repo: edge-cluster-1
    package: upf-edge1
  
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-cluster-1
  
  adoptionPolicy: adoptExisting
  deletionPolicy: delete
```

## Repository Structure Alignment

### Your nephio-blueprints repo should match:

```
nephio-blueprints/                    # Git repo
├── infrastructure/
│   ├── baseline/                     ← package: infrastructure/baseline
│   │   ├── namespace.yaml
│   │   └── Kptfile
│   ├── multus/                       ← package: infrastructure/multus
│   │   ├── daemonset.yaml
│   │   └── Kptfile
│   └── addons/                       ← package: infrastructure/addons
│       └── Kptfile
│
└── workloads/
    ├── oai-ran/
    │   └── gnb/                      ← package: workloads/oai-ran/gnb
    │       ├── interface-n2.yaml
    │       ├── interface-n3.yaml
    │       ├── interface-ru.yaml
    │       ├── networkinstance-control.yaml
    │       └── Kptfile
    │
    └── sdcore/
        └── upf/                      ← package: workloads/sdcore/upf
            ├── interface-n3.yaml
            ├── interface-n6.yaml
            ├── interface-n4.yaml
            └── Kptfile
```

**The `package:` path in PackageVariant = directory path in repo**

## Complete Deployment Flow

### Step 1: Register Repository

```bash
# Apply Repository CR
kubectl apply -f management-config/repositories/nephio-blueprints-repo.yaml

# Verify registration
kubectl get repositories

# Check Porch can see packages
kubectl get packagerevisions | grep nephio-blueprints
```

### Step 2: Create Management Resources

```bash
# Apply IP pools
kubectl apply -f management-config/ip-pools/

# Apply WorkloadCluster
kubectl apply -f management-config/workloadclusters/

# Verify
kubectl get ipprefixes
kubectl get workloadclusters
```

### Step 3: Deploy Infrastructure

```bash
# Apply infrastructure PackageVariants
kubectl apply -f management-config/packagevariants/baseline-pv.yaml

# Watch package creation
kubectl get packagerevisions --watch

# Should see packages created in edge-cluster-1 repo:
# - baseline-edge1-v1
# - multus-edge1-v1
# - addons-edge1-v1
```

### Step 4: Deploy Workloads

```bash
# Apply workload PackageVariants
kubectl apply -f management-config/packagevariants/oai-gnb-pv.yaml
kubectl apply -f management-config/packagevariants/upf-pv.yaml

# Watch specialization
kubectl get packagerevisions -n oai-ran --watch

# Check readiness gates
kubectl get packagerevision oai-gnb-edge1-v1 -n oai-ran -o yaml | grep conditions -A 20
```

### Step 5: Approve Packages

```bash
# Once all conditions are True:

# Propose
kpt alpha rpkg propose oai-gnb-edge1-v1 -n oai-ran

# Approve
kpt alpha rpkg approve oai-gnb-edge1-v1 -n oai-ran
```

## Verification

### Check Repository Registration

```bash
# Repository should be visible
kubectl get repository nephio-blueprints -o yaml

# Should show:
# status:
#   type: git
#   conditions:
#   - type: Ready
#     status: "True"
```

### Check Package Discovery

```bash
# Porch should discover packages from repo
kubectl get packagerevisions | grep nephio-blueprints

# Should show upstream packages:
# nephio-blueprints-infrastructure-baseline-main
# nephio-blueprints-infrastructure-multus-main
# nephio-blueprints-workloads-oai-ran-gnb-main
```

### Check PackageVariant Processing

```bash
# PackageVariant should create downstream packages
kubectl get packagevariant oai-gnb-edge1 -o yaml

# Status should show:
# status:
#   conditions:
#   - type: Ready
#     status: "True"
#   downstreamTargets:
#   - name: oai-gnb-edge1
#     repo: edge-cluster-1
```

## Common Issues and Solutions

### Issue 1: Package Not Found

```
Error: upstream package not found
```

**Solution:**
- Verify path matches: `package: workloads/oai-ran/gnb` = directory `workloads/oai-ran/gnb/` in repo
- Check Kptfile exists in that directory
- Verify repository registered: `kubectl get repositories`

### Issue 2: Repository Not Ready

```
Repository not ready
```

**Solution:**
```bash
# Check repository status
kubectl describe repository nephio-blueprints

# Check Porch can access Git
kubectl logs -n porch-system -l app=porch-server
```

### Issue 3: Package Path Mismatch

```yaml
# ❌ WRONG
upstream:
  package: gnb                # Missing full path

# ✅ CORRECT
upstream:
  package: workloads/oai-ran/gnb
```

### Issue 4: Downstream Repo Not Found

```
Error: downstream repo not found
```

**Solution:**
```bash
# Register edge cluster repo
kubectl apply -f - <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: edge-cluster-1
spec:
  type: git
  content: Package
  deployment: true           # This is a deployment target
  git:
    repo: http://gitea.gitea.svc.cluster.local:3000/nephio/edge-cluster-1.git
    branch: main
EOF
```

## Summary

```
┌─────────────────────────────────────────────────────────────────┐
│              Your PackageVariant References Are CORRECT          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│ ✅ repo: nephio-blueprints                                      │
│    → Matches Repository CR name                                 │
│                                                                  │
│ ✅ package: infrastructure/baseline                             │
│    → Matches directory path in git repo                         │
│                                                                  │
│ ✅ package: infrastructure/multus                               │
│    → Matches directory path in git repo                         │
│                                                                  │
│ ✅ package: workloads/oai-ran/gnb                               │
│    → Matches directory path in git repo                         │
│                                                                  │
│ ✅ revision: main                                               │
│    → Git branch name                                            │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

Your understanding is perfect! The `package:` field is simply the **directory path within your nephio-blueprints repo** where the Kptfile and package resources live. 🎉
