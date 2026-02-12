# Kptfile Status and Conditions Guide for Nephio

## Short Answer

**Yes, you typically DO need status/conditions in the Kptfile**, but they are **automatically managed by Nephio controllers** (PackageVariant controller, Porch, etc.). You don't usually write them manually in your initial Kptfile.

## Understanding Kptfile Status and Conditions

### What Are They?

The Kptfile has two related but distinct sections:

1. **`info.readinessGates`** - Declares what conditions must be met before package is "ready"
2. **`status.conditions`** - Shows current status of those conditions (managed by controllers)

### When Do You Need Them?

**For SD-Core with Interface resources**, you need readiness gates for:
- ✅ **WorkloadCluster injection** - Ensures cluster-specific config is injected
- ✅ **Interface processing** - Ensures Interface resources are processed by interface-fn
- ✅ **IP allocation** - Ensures IPClaim resources get allocated IPs
- ✅ **NAD generation** - Ensures NADs are created by nad-fn

## Complete Kptfile Structure for SD-Core UPF

Here's what your Kptfile should look like with proper readiness gates:

```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: upf-package
  namespace: upf
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: SD-Core UPF deployment package with Nephio Interface resources
  
  # Readiness Gates - Define conditions that must be True before package is ready
  readinessGates:
  - conditionType: config.injection.WorkloadCluster.workload-cluster
  - conditionType: req.nephio.org.interface.n3
  - conditionType: req.nephio.org.interface.n6
  - conditionType: req.nephio.org.interface.n4
  - conditionType: ipam.nephio.org.ipclaim.n3
  - conditionType: ipam.nephio.org.ipclaim.n6
  - conditionType: ipam.nephio.org.ipclaim.n4

pipeline:
  mutators:
  # interface-fn creates IPClaim resources from Interface resources
  - image: docker.io/nephio/interface-fn:v2.0.0
    configMap:
      debug: "true"
  
  # nad-fn generates NetworkAttachmentDefinitions from IPClaim status
  - image: docker.io/nephio/nad-fn:v2.0.0
    configMap:
      debug: "true"
  
  validators:
  # Validate all resources
  - image: gcr.io/kpt-fn/kubeval:v0.3.0
    configMap:
      ignore_missing_schemas: "true"

# Status section - Automatically populated by controllers
# DO NOT manually write this in your initial Kptfile
# It will be added and updated by Nephio controllers
status:
  conditions:
  # WorkloadCluster injection status
  - type: config.injection.WorkloadCluster.workload-cluster
    status: "True"
    message: "injected resource 'edge-cluster-1' from cluster"
    reason: ConfigInjected
    lastTransitionTime: "2026-02-12T10:00:00Z"
  
  # Interface n3 processing status
  - type: req.nephio.org.interface.n3
    status: "True"
    message: "Interface n3 processed successfully"
    reason: InterfaceProcessed
    lastTransitionTime: "2026-02-12T10:00:05Z"
  
  # Interface n6 processing status
  - type: req.nephio.org.interface.n6
    status: "True"
    message: "Interface n6 processed successfully"
    reason: InterfaceProcessed
    lastTransitionTime: "2026-02-12T10:00:05Z"
  
  # Interface n4 processing status
  - type: req.nephio.org.interface.n4
    status: "True"
    message: "Interface n4 processed successfully"
    reason: InterfaceProcessed
    lastTransitionTime: "2026-02-12T10:00:05Z"
  
  # IPClaim n3 allocation status
  - type: ipam.nephio.org.ipclaim.n3
    status: "True"
    message: "IP allocated: 192.168.252.3/32"
    reason: IPAllocated
    lastTransitionTime: "2026-02-12T10:00:10Z"
  
  # IPClaim n6 allocation status
  - type: ipam.nephio.org.ipclaim.n6
    status: "True"
    message: "IP allocated: 192.168.250.3/32"
    reason: IPAllocated
    lastTransitionTime: "2026-02-12T10:00:10Z"
  
  # IPClaim n4 allocation status
  - type: ipam.nephio.org.ipclaim.n4
    status: "True"
    message: "IP allocated: 10.0.0.3/32"
    reason: IPAllocated
    lastTransitionTime: "2026-02-12T10:00:10Z"
```

## How Readiness Gates Work

### The Lifecycle

```
┌──────────────────────────────────────────────────────────────┐
│ 1. Initial Kptfile (what you write)                          │
│    - Has info.readinessGates defined                         │
│    - NO status section                                       │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. PackageVariant creates draft package                      │
│    - Adds initial status.conditions (all False)              │
│    - Adds pipeline mutators from PackageVariant              │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. Controllers inject required resources                     │
│    - WorkloadCluster injected → condition True               │
│    - Updates status.conditions                               │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. Pipeline functions execute                                │
│    - interface-fn creates IPClaim → condition True           │
│    - IPAM allocates IPs → condition True                     │
│    - nad-fn creates NADs → condition True                    │
└────────────────────┬─────────────────────────────────────────┘
                     │
                     ▼
┌──────────────────────────────────────────────────────────────┐
│ 5. Package is READY when all conditions are True             │
│    - Can be PROPOSED and APPROVED                            │
│    - Deployed to target cluster                              │
└──────────────────────────────────────────────────────────────┘
```

### Readiness Gate Naming Convention

The `conditionType` follows this pattern:

For **Interface resources**:
```
req.nephio.org.interface.<interface-name>
```
Examples:
- `req.nephio.org.interface.n3`
- `req.nephio.org.interface.n6`
- `req.nephio.org.interface.n4`

For **IPClaim resources**:
```
ipam.nephio.org.ipclaim.<interface-name>
```
Examples:
- `ipam.nephio.org.ipclaim.n3`
- `ipam.nephio.org.ipclaim.n6`

For **WorkloadCluster injection**:
```
config.injection.WorkloadCluster.<resource-name>
```
Example:
- `config.injection.WorkloadCluster.workload-cluster`

## What You Should Write vs What's Auto-Generated

### ✅ What YOU write in upstream package:

```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: upf-package
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: SD-Core UPF deployment package
  
  # YOU WRITE THESE - Declare what conditions are needed
  readinessGates:
  - conditionType: config.injection.WorkloadCluster.workload-cluster
  - conditionType: req.nephio.org.interface.n3
  - conditionType: req.nephio.org.interface.n6
  - conditionType: req.nephio.org.interface.n4
  - conditionType: ipam.nephio.org.ipclaim.n3
  - conditionType: ipam.nephio.org.ipclaim.n6
  - conditionType: ipam.nephio.org.ipclaim.n4

pipeline:
  mutators:
  - image: docker.io/nephio/interface-fn:v2.0.0
  - image: docker.io/nephio/nad-fn:v2.0.0
  
  validators:
  - image: gcr.io/kpt-fn/kubeval:v0.3.0
    configMap:
      ignore_missing_schemas: "true"

# NO STATUS SECTION IN YOUR INITIAL FILE
```

### 🤖 What Nephio AUTO-GENERATES:

```yaml
# This gets added automatically - DO NOT manually write
status:
  conditions:
  - type: config.injection.WorkloadCluster.workload-cluster
    status: "False"  # Initially False
    message: "waiting for injection"
    reason: Waiting
  - type: req.nephio.org.interface.n3
    status: "False"
    message: "waiting for processing"
    reason: Waiting
  # ... etc for all readinessGates
```

## Minimal Kptfile (What You Actually Need to Write)

For SD-Core UPF, here's the MINIMAL Kptfile you need:

```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: upf-package
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: SD-Core UPF deployment package
  readinessGates:
  - conditionType: config.injection.WorkloadCluster.workload-cluster
  - conditionType: req.nephio.org.interface.n3
  - conditionType: req.nephio.org.interface.n6
  - conditionType: req.nephio.org.interface.n4

pipeline:
  mutators:
  - image: docker.io/nephio/interface-fn:v2.0.0
  - image: docker.io/nephio/nad-fn:v2.0.0
```

That's it! The rest is auto-managed.

## When NOT to Use Readiness Gates

You can skip readiness gates if:
- ❌ Simple package with no dependencies
- ❌ No resource injection needed
- ❌ No IP allocation required
- ❌ Static configuration only

For SD-Core with dynamic networking, you **NEED** readiness gates.

## Checking Readiness Status

### Via kubectl

```bash
# Get package revision
kubectl get packagerevisions -n upf

# Check conditions
kubectl get packagerevision upf-edge1-v1 -n upf -o jsonpath='{.status.conditions}' | jq .

# Check if ready
kubectl get packagerevision upf-edge1-v1 -n upf -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}'
```

### Via Nephio UI

In the Nephio Web UI, you'll see a visual indicator showing:
- 🟡 Yellow: Conditions pending
- 🟢 Green: All conditions satisfied
- 🔴 Red: Error in processing

## Troubleshooting Stuck Conditions

### Condition Not Turning True

**Problem**: `req.nephio.org.interface.n3` stays False

**Check**:
1. Does Interface resource exist in package?
```bash
kubectl get packagerevisionresources upf-edge1-v1 -n upf -o yaml | grep -A 10 "kind: Interface"
```

2. Is interface-fn in pipeline?
```bash
kubectl get packagerevision upf-edge1-v1 -n upf -o jsonpath='{.spec.pipeline.mutators[*].image}'
```

3. Check function execution logs (via Porch)

**Problem**: `ipam.nephio.org.ipclaim.n3` stays False

**Check**:
1. Does IPClaim exist?
```bash
kubectl get packagerevisionresources upf-edge1-v1 -n upf -o yaml | grep -A 10 "kind: IPClaim"
```

2. Is IPClaim status populated?
```bash
kubectl get packagerevisionresources upf-edge1-v1 -n upf -o yaml | grep -A 5 "status:"
```

3. Check IPAM controller:
```bash
kubectl get pods -n nephio-system | grep ipam
kubectl logs -n nephio-system <ipam-pod>
```

## Best Practices

1. **Always Define Readiness Gates** for packages with:
   - Interface resources
   - IPClaim resources
   - Config injection requirements

2. **Use Consistent Naming**:
   - Interface names: `n3`, `n6`, `n4` (match 3GPP spec)
   - Condition types: match resource names exactly

3. **Monitor Conditions**:
   - Don't PROPOSE package until all conditions are True
   - Use Nephio UI or `kubectl` to watch progress

4. **Don't Manually Edit Status**:
   - Let controllers manage `status.conditions`
   - Only edit `info.readinessGates`

5. **Include All Dependencies**:
   ```yaml
   readinessGates:
   - conditionType: config.injection.WorkloadCluster.workload-cluster
   - conditionType: req.nephio.org.interface.n3
   - conditionType: req.nephio.org.interface.n6
   - conditionType: req.nephio.org.interface.n4
   # Add any other resources your package depends on
   ```

## Summary

**YES**, you need `readinessGates` in your Kptfile for SD-Core packages with Interface resources.

**Structure**:
```yaml
info:
  readinessGates:           # ✅ YOU WRITE THIS
  - conditionType: ...

status:
  conditions:               # 🤖 AUTO-GENERATED
  - type: ...
    status: ...
```

**For each Interface**, add TWO readiness gates:
1. One for the Interface itself: `req.nephio.org.interface.<name>`
2. One for its IPClaim: `ipam.nephio.org.ipclaim.<name>`

**Plus** one for WorkloadCluster injection:
- `config.injection.WorkloadCluster.workload-cluster`

This ensures your package won't be deployed until all networking is properly configured!
