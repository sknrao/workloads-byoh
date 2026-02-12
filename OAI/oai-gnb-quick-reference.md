# OAI gNB with Nephio - Quick Reference

## Network Interface Summary

### Monolithic gNB
| Interface | Purpose | IP Example | Port |
|-----------|---------|------------|------|
| N2 | Control to AMF | 10.1.2.18 | 38412 (SCTP) |
| N3 | User plane to UPF | 10.1.3.18 | 2152 (UDP/GTP-U) |
| RU | To Radio Unit (Optional) | 10.2.6.16 | - |

**Total Interfaces**: 2-3 (N2, N3, optionally RU)  
**Readiness Gates**: 7 (1 WorkloadCluster + 3 Interface + 3 IPClaim)

### Split CU
| Interface | Purpose | IP Example | Port |
|-----------|---------|------------|------|
| N2 | Control to AMF | 10.1.2.18 | 38412 (SCTP) |
| F1-C | F1 Control to DU | 10.2.5.16 | 38472 (SCTP) |
| E1 | CU-CP to CU-UP | 10.2.1.16 | - |

**Total Interfaces**: 3  
**Readiness Gates**: 7 (1 WorkloadCluster + 3 Interface + 3 IPClaim)

### Split DU
| Interface | Purpose | IP Example | Port |
|-----------|---------|------------|------|
| F1 | F1 to CU (C+U) | 10.2.5.18 | 38472/2152 |
| N3 | User plane to UPF | 10.1.3.17 | 2152 (UDP/GTP-U) |
| RU | To Radio Unit (Optional) | 10.2.6.16 | - |

**Total Interfaces**: 2-3  
**Readiness Gates**: 7 (1 WorkloadCluster + 3 Interface + 3 IPClaim)

## Deployment Comparison: SD-Core vs OAI gNB

| Aspect | SD-Core UPF | OAI gNB Monolithic | OAI CU | OAI DU |
|--------|-------------|-------------------|---------|--------|
| **Core Function** | User Plane Function | Base Station | Central Unit | Distributed Unit |
| **Key Interfaces** | N3, N6, N4 | N2, N3 | N2, F1-C, E1 | F1, N3 |
| **Connects To** | gNB (N3), DN (N6), SMF (N4) | AMF (N2), UPF (N3) | AMF (N2), DU (F1) | CU (F1), UPF (N3) |
| **Total NADs** | 3 | 2-3 | 3 | 2-3 |
| **Namespace** | upf | oai-ran | oai-cu | oai-du |

## IP Allocation Planning Template

| Network | CIDR | Gateway | Purpose | Used By |
|---------|------|---------|---------|---------|
| **Control** | 10.1.2.0/24 | 10.1.2.1 | N2 (NGAP) | AMF, gNB/CU |
| **User Plane** | 10.1.3.0/24 | 10.1.3.1 | N3 (GTP-U) | UPF, gNB/DU |
| **Midhaul** | 10.2.5.0/24 | 10.2.5.1 | F1 (F1AP) | CU, DU |
| **Fronthaul** | 10.2.6.0/24 | 10.2.6.1 | RU (USRP) | DU, RU |
| **CU-CP/UP** | 10.2.1.0/24 | 10.2.1.1 | E1 (E1AP) | CU-CP, CU-UP |

## Kptfile Readiness Gates

### Monolithic gNB (7 gates)
```yaml
readinessGates:
- conditionType: config.injection.WorkloadCluster.workload-cluster  # 1
- conditionType: req.nephio.org.interface.n2                         # 2
- conditionType: req.nephio.org.interface.n3                         # 3
- conditionType: req.nephio.org.interface.ru                         # 4
- conditionType: ipam.nephio.org.ipclaim.n2                          # 5
- conditionType: ipam.nephio.org.ipclaim.n3                          # 6
- conditionType: ipam.nephio.org.ipclaim.ru                          # 7
```

### Split CU (7 gates)
```yaml
readinessGates:
- conditionType: config.injection.WorkloadCluster.workload-cluster  # 1
- conditionType: req.nephio.org.interface.n2                         # 2
- conditionType: req.nephio.org.interface.f1c                        # 3
- conditionType: req.nephio.org.interface.e1                         # 4
- conditionType: ipam.nephio.org.ipclaim.n2                          # 5
- conditionType: ipam.nephio.org.ipclaim.f1c                         # 6
- conditionType: ipam.nephio.org.ipclaim.e1                          # 7
```

### Split DU (7 gates)
```yaml
readinessGates:
- conditionType: config.injection.WorkloadCluster.workload-cluster  # 1
- conditionType: req.nephio.org.interface.f1                         # 2
- conditionType: req.nephio.org.interface.n3                         # 3
- conditionType: req.nephio.org.interface.ru                         # 4
- conditionType: ipam.nephio.org.ipclaim.f1                          # 5
- conditionType: ipam.nephio.org.ipclaim.n3                          # 6
- conditionType: ipam.nephio.org.ipclaim.ru                          # 7
```

## Common Commands

### Create IP Pools
```bash
kubectl apply -f - <<EOF
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
EOF
```

### Verify Package Processing
```bash
# Watch package status
kubectl get packagerevisions -n oai-ran --watch

# Check conditions
kubectl get packagerevision gnb-edge-v1 -n oai-ran -o yaml | yq '.status.conditions'

# View generated NADs
kubectl get network-attachment-definitions -n oai-ran
```

### Check gNB Pod Networking
```bash
# Get pod name
POD=$(kubectl get pods -n oai-ran -l app=oai-gnb -o name | head -1)

# View interfaces
kubectl exec -n oai-ran $POD -- ip addr

# Test N2 connectivity to AMF
kubectl exec -n oai-ran $POD -- ping 10.1.2.10

# Test N3 connectivity to UPF
kubectl exec -n oai-ran $POD -- ping 10.1.3.3
```

## Deployment Workflow

### Phase 1: Management Cluster Setup
```bash
# 1. Create IP pools
kubectl apply -f ip-pools.yaml

# 2. Create WorkloadCluster
kubectl apply -f workload-cluster.yaml

# 3. Verify
kubectl get ipprefixes
kubectl get workloadclusters
```

### Phase 2: Package Deployment
```bash
# 1. Create PackageVariant
kubectl apply -f - <<EOF
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: gnb-edge-cluster-1
  namespace: default
spec:
  upstream:
    repo: gnb-blueprints
    package: gnb-monolithic-blueprint
    revision: v1
  downstream:
    repo: edge-cluster-1-repo
    package: gnb-edge-cluster-1
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-cluster-1
EOF

# 2. Watch progression
kubectl get packagerevision gnb-edge-cluster-1-v1 -n oai-ran --watch
```

### Phase 3: Approve and Deploy
```bash
# 1. Propose package
kpt alpha rpkg propose gnb-edge-cluster-1-v1 -n oai-ran

# 2. Approve package
kpt alpha rpkg approve gnb-edge-cluster-1-v1 -n oai-ran

# 3. Switch to workload cluster and verify
kubectl config use-context edge-cluster-1
kubectl get network-attachment-definitions -n oai-ran
```

### Phase 4: Deploy OAI with Helm
```bash
# Deploy gNB
helm install -n oai-ran oai-gnb oai-charts/oai-gnb -f gnb-values.yaml

# Verify
kubectl get pods -n oai-ran
kubectl logs -n oai-ran <gnb-pod>
```

## Troubleshooting Quick Guide

| Issue | Check | Solution |
|-------|-------|----------|
| Interface not created | `kubectl logs -n kube-system <multus-pod>` | Verify NAD exists and physical interface is available |
| IPClaim not allocated | `kubectl get ipprefixes` | Ensure IP pool exists for networkInstance |
| Package stuck in Draft | `kubectl get packagerevision <n> -o yaml \| grep conditions` | Check which readiness gate is False |
| gNB can't reach AMF | `kubectl exec <gnb-pod> -- ping <amf-ip>` | Verify routes and gateway configuration |
| NGAP connection failed | `kubectl logs <gnb-pod>` | Check gNB config has correct AMF IP |

## Architecture Decision Matrix

Choose your architecture:

| Use Case | Architecture | Interfaces | Complexity |
|----------|--------------|------------|------------|
| **Lab/Testing** | Monolithic | N2, N3 | Low |
| **RF Simulator** | Monolithic | N2, N3 | Low |
| **With USRP** | Monolithic | N2, N3, RU | Medium |
| **Edge Deployment** | Split CU/DU | CU: N2,F1-C,E1<br>DU: F1,N3,RU | High |
| **Cloud RAN** | Split CU/DU | CU: N2,F1-C,E1<br>DU: F1,N3,RU | High |

## Network Connectivity Matrix

```
Monolithic gNB:
  N2 ──────> AMF (10.1.2.10)
  N3 ──────> UPF (10.1.3.3)
  RU ──────> USRP (10.2.6.x)

Split Architecture:
  CU:
    N2 ────> AMF (10.1.2.10)
    F1-C ──> DU (10.2.5.18)
    E1 ────> CU-UP (10.2.1.x)
  
  DU:
    F1 ────> CU (10.2.5.16)
    N3 ────> UPF (10.1.3.3)
    RU ────> USRP (10.2.6.x)
```

## Pre-Deployment Checklist

### Management Cluster
- [ ] Multus CNI installed
- [ ] IP pools created (IPPrefix resources)
- [ ] WorkloadCluster defined
- [ ] Package repository configured

### Workload Cluster
- [ ] Multus CNI installed
- [ ] Physical interfaces identified
- [ ] Network connectivity verified
- [ ] OAI Helm charts available

### Package Preparation
- [ ] Interface resources created
- [ ] NetworkInstance resources defined
- [ ] Kptfile with readiness gates
- [ ] Namespace created

### Post-Deployment
- [ ] All conditions True
- [ ] NADs generated
- [ ] IPs allocated
- [ ] gNB pods running
- [ ] Connectivity verified

## Resources Provided

1. **oai-gnb-nad-guide.md** - NAD fundamentals for OAI gNB
2. **oai-gnb-nephio-guide.md** - Nephio Interface/IPClaim guide
3. **oai-gnb-monolithic-package.yaml** - Complete monolithic package
4. **oai-cu-du-split-package.yaml** - Complete split CU/DU packages
5. **This quick reference** - Fast lookup guide

Happy deploying! 🚀
