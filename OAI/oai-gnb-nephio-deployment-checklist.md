# OAI gNB Nephio Deployment - Complete NAD Requirements Checklist

## Quick Answer

**YES**, the NAD package I provided is **sufficient** for NAD creation, BUT you also need several other components for a complete OAI gNB deployment with Nephio.

## What You Have

✅ **Cluster Infrastructure** (You mentioned you have these):
- cluster-baseline
- addons  
- multus
- whereabouts (IPAM)

✅ **NAD Blueprint** (From my earlier packages):
- Interface resources (N2, N3, RU)
- NetworkInstance definitions
- Kptfile with readiness gates
- IP pool configurations

## What You Still Need for Complete OAI Deployment

### 1. OAI RAN Operator Package ⚠️ **REQUIRED**

**Purpose**: The operator that watches for NFDeployment CRs and creates the actual gNB pods.

**From Nephio Catalog**:
```
Repository: https://github.com/nephio-project/catalog
Location: workloads/oai/oai-ran-operator
```

**What it does**:
- Watches `NFDeployment` CRD (from nephio/api)
- Creates gNB Deployment/StatefulSet
- **Automatically creates NADs** based on Interface resources
- Configures gNB using NFConfig CR
- Manages pod lifecycle

**Apply via PackageVariant**:
```yaml
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: oai-ran-operators
  namespace: default
spec:
  upstream:
    repo: catalog-workloads-oai-ran
    package: oai-ran-operator
    revision: main
  downstream:
    repo: edge-cluster-1
    package: oai-ran-operators
```

### 2. OAI gNB Deployment Package ⚠️ **REQUIRED**

**Purpose**: The actual NFDeployment CR that triggers the operator.

**From Nephio Catalog**:
```
Repository: https://github.com/nephio-project/catalog
Packages:
- pkg-example-cucp-bp (for CU-CP)
- pkg-example-cuup-bp (for CU-UP)  
- pkg-example-du-bp (for DU)
- pkg-example-gnb-mono-bp (for Monolithic - if available)
```

**Example NFDeployment CR** (from catalog):
```yaml
apiVersion: workload.nephio.org/v1alpha1
kind: NFDeployment
metadata:
  name: cucp-edge1
  namespace: oai-ran-cucp
spec:
  provider: cucp.openairinterface.org
  capacity:
    maxDownlinkThroughput: 5G
    maxUplinkThroughput: 2G
  interfaces:
  - name: n2
    ipv4:
      address: 10.1.2.18/24
      gateway: 10.1.2.1
  - name: f1c
    ipv4:
      address: 10.2.5.16/24
      gateway: 10.2.5.1
  parametersRefs:
  - name: cucp-edge1-config
    apiVersion: workload.nephio.org/v1alpha1
    kind: NFConfig
```

**Apply via PackageVariant**:
```yaml
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: oai-cucp-edge1
  namespace: default
spec:
  upstream:
    repo: catalog-workloads-oai-ran
    package: pkg-example-cucp-bp
    revision: main
  downstream:
    repo: edge-cluster-1
    package: oai-cucp-edge1
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-cluster-1
```

### 3. Nephio API CRDs ⚠️ **REQUIRED**

**Purpose**: Custom Resource Definitions that the operator watches.

**From Nephio API Repository**:
```
Repository: https://github.com/nephio-project/api
Required CRDs:
- workload.nephio.org/v1alpha1/NFDeployment
- workload.nephio.org/v1alpha1/NFConfig
- req.nephio.org/v1alpha1/Interface
- ipam.resource.nephio.org/v1alpha1/IPClaim
- infra.nephio.org/v1alpha1/WorkloadCluster
- infra.nephio.org/v1alpha1/NetworkInstance
```

**These are usually installed with Nephio management cluster, but verify**:
```bash
kubectl get crd nfdeployments.workload.nephio.org
kubectl get crd nfconfigs.workload.nephio.org
kubectl get crd interfaces.req.nephio.org
```

### 4. IP Pools (IPPrefix Resources) ⚠️ **REQUIRED**

**Purpose**: IP address pools for IPAM controller to allocate from.

**You need to create these** (as shown in my earlier examples):
```yaml
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: control-pool
  namespace: default
spec:
  prefix: 10.1.2.0/24
  networkInstance:
    name: vpc-control
---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: userplane-pool
  namespace: default
spec:
  prefix: 10.1.3.0/24
  networkInstance:
    name: vpc-userplane
---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: fronthaul-pool
  namespace: default
spec:
  prefix: 10.2.6.0/24
  networkInstance:
    name: vpc-fronthaul
```

### 5. WorkloadCluster Resource ⚠️ **REQUIRED**

**Purpose**: Provides cluster-specific context for Interface resources.

**Example**:
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
  masterInterface: ens3
```

## Complete Deployment Flow

### Phase 1: Management Cluster Setup

```bash
# 1. Verify Nephio CRDs are installed
kubectl get crd | grep nephio

# 2. Create IP Pools
kubectl apply -f ip-pools.yaml

# 3. Create WorkloadCluster
kubectl apply -f workload-cluster.yaml

# 4. Deploy OAI RAN Operator to Edge Cluster
kubectl apply -f oai-ran-operator-packagevariant.yaml

# Wait for operator to be running
kubectl get pods -n oai-ran-operators --context edge-cluster-1
```

### Phase 2: Create Network Blueprint

```bash
# 5. Apply your Interface/NetworkInstance package
# (The one I provided earlier)
kubectl apply -f oai-gnb-monolithic-package.yaml

# This creates the blueprint with:
# - Interface resources (N2, N3, RU)
# - NetworkInstance resources
# - Kptfile with readiness gates
```

### Phase 3: Deploy gNB

```bash
# 6. Create PackageVariant for gNB deployment
kubectl apply -f gnb-deployment-packagevariant.yaml

# 7. Watch the package being specialized
kubectl get packagerevisions -A --watch

# The flow:
# - PackageVariant clones blueprint
# - interface-fn creates IPClaim resources
# - IPAM allocates IPs
# - nad-fn creates NADs
# - All conditions become True
```

### Phase 4: Approve Deployment

```bash
# 8. Propose the package
kpt alpha rpkg propose gnb-edge1-v1 -n oai-ran

# 9. Approve the package
kpt alpha rpkg approve gnb-edge1-v1 -n oai-ran

# 10. Watch deployment in workload cluster
kubectl get pods -n oai-ran --context edge-cluster-1 --watch
```

## What the OAI Operator Does with NADs

**Critical Understanding**: The OAI RAN operator has **TWO ways** to create NADs:

### Option 1: Operator Creates NADs Automatically

From the operator source code (`network_attachment_definitions.go`):
```go
// The operator can create NADs based on Interface resources
func (r *RANDeploymentReconciler) createNetworkAttachmentDefinition(...)
```

**When this happens**:
- Operator reads Interface resources from package
- Reads IPClaim status (IP addresses allocated)
- **Generates NAD automatically**
- Applies NAD to cluster

### Option 2: Nephio NAD-fn Creates NADs

**When this happens**:
- nad-fn (KRM function) runs in package pipeline
- Reads Interface and IPClaim resources
- **Generates NAD as part of package**
- ConfigSync deploys NAD to cluster

**Both methods work!** Nephio typically uses **Option 2** (nad-fn in pipeline).

## NAD Verification Checklist

After deployment, verify NADs are created:

```bash
# 1. Check NADs exist
kubectl get network-attachment-definitions -n oai-ran --context edge-cluster-1

# Expected output:
# NAME   AGE
# n2     5m
# n3     5m
# ru     5m

# 2. Check NAD details
kubectl describe network-attachment-definition n2 -n oai-ran

# 3. Check gNB pod has interfaces
kubectl get pod -n oai-ran -l app=oai-gnb -o jsonpath='{.items[0].metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' | jq .

# Expected: Multiple interfaces with IPs
```

## Complete Package List You Need

### From Nephio Catalog:
1. ✅ **oai-ran-operator** - The operator itself
2. ✅ **pkg-example-cucp-bp** OR **pkg-example-gnb-mono-bp** - Deployment package

### You Create:
3. ✅ **Interface/NetworkInstance package** - ← **My package covers this**
4. ✅ **IP Pools (IPPrefix)** - Simple YAML
5. ✅ **WorkloadCluster** - Simple YAML
6. ✅ **PackageVariants** - To instantiate packages

### Your Existing Infrastructure (Already have):
7. ✅ cluster-baseline
8. ✅ addons
9. ✅ multus
10. ✅ whereabouts

## Answer to Your Specific Question

> "If I use that NAD package, is that sufficient to deploy OAI gnb operator and kpt packages using Nephio?"

**Partial YES with clarification**:

✅ **For NAD creation specifically**: YES, the Interface/NetworkInstance package I provided IS sufficient. When processed by Nephio, it will create the NADs.

⚠️ **For complete gNB deployment**: NO, you also need:
- OAI RAN Operator (from Nephio catalog)
- NFDeployment package (from Nephio catalog)
- IP Pools (simple YAML to create)
- WorkloadCluster (simple YAML to create)

## Minimal Additional Work Required

Here's what you need to add to what I provided:

### 1. Create IP Pools (5 minutes)

```yaml
# File: ip-pools.yaml
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: control-pool
  namespace: default
spec:
  prefix: 10.1.2.0/24
  networkInstance:
    name: vpc-control
---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: userplane-pool
  namespace: default
spec:
  prefix: 10.1.3.0/24
  networkInstance:
    name: vpc-userplane
---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: fronthaul-pool
  namespace: default
spec:
  prefix: 10.2.6.0/24
  networkInstance:
    name: vpc-fronthaul
```

### 2. Create WorkloadCluster (2 minutes)

```yaml
# File: workload-cluster.yaml
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
  masterInterface: ens3
```

### 3. Create PackageVariants (10 minutes)

```yaml
# File: oai-operator-pv.yaml
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: oai-ran-operators-edge1
  namespace: default
spec:
  upstream:
    repo: catalog-workloads-oai-ran
    package: oai-ran-operator
    revision: main
  downstream:
    repo: edge-cluster-1
    package: oai-ran-operators

---
# File: oai-gnb-pv.yaml
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: oai-gnb-edge1
  namespace: default
spec:
  upstream:
    repo: catalog-workloads-oai-ran
    package: pkg-example-gnb-mono-bp  # Or cucp/cuup/du
    revision: main
  downstream:
    repo: edge-cluster-1
    package: oai-gnb-edge1
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-cluster-1
```

## Summary

**Your NAD package (Interface resources) IS sufficient for the NAD portion**, but for complete deployment you need:

| Component | Status | Source |
|-----------|--------|--------|
| **Interface/NetworkInstance package** | ✅ Provided | My earlier files |
| **OAI RAN Operator** | ⚠️ Need to add | Nephio catalog |
| **NFDeployment package** | ⚠️ Need to add | Nephio catalog |
| **IP Pools** | ⚠️ Need to create | Simple YAML (provided above) |
| **WorkloadCluster** | ⚠️ Need to create | Simple YAML (provided above) |
| **PackageVariants** | ⚠️ Need to create | Simple YAML (provided above) |
| **Multus** | ✅ You have | Your infrastructure |
| **Whereabouts** | ✅ You have | Your infrastructure |
| **Cluster baseline** | ✅ You have | Your infrastructure |

**Total additional work**: ~20-30 minutes to create the missing YAMLs.

Would you like me to create the complete, ready-to-use YAML files for all the missing pieces?
