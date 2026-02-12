# PackageVariant Usage Guide for SD-Core and OAI-RAN

## Overview

This guide explains how to use PackageVariants to deploy NADs for SD-Core UPF and OAI gNB across multiple sites. PackageVariants enable automatic instantiation of site-specific packages from upstream blueprints.

## What is a PackageVariant?

A **PackageVariant** is a Nephio resource that:
1. Takes an upstream blueprint package
2. Applies site-specific customizations
3. Creates a downstream package for a specific cluster/site
4. Injects cluster-specific resources (like WorkloadCluster)
5. Applies mutations through the pipeline

```
┌─────────────────┐
│    Upstream     │
│   Blueprint     │  (Generic package)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ PackageVariant  │  (Defines customization)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Downstream    │  (Site-specific package)
│    Package      │
└─────────────────┘
```

## Architecture Overview

### SD-Core UPF Deployment

```
Management Cluster:
├── blueprints/upf-blueprint (upstream)
├── PackageVariant: upf-edge-site-1
├── PackageVariant: upf-edge-site-2
└── PackageVariant: upf-regional-site

Workload Clusters:
├── edge-site-1/upf-edge-site-1 (downstream)
├── edge-site-2/upf-edge-site-2 (downstream)
└── regional-site/upf-regional-site (downstream)
```

### OAI gNB Monolithic Deployment

```
Management Cluster:
├── blueprints/gnb-monolithic-blueprint (upstream)
├── PackageVariant: gnb-monolithic-edge-site-1
├── PackageVariant: gnb-monolithic-edge-site-2
└── PackageVariant: gnb-monolithic-lab-usrp

Workload Clusters:
├── edge-site-1/gnb-monolithic-edge-site-1
├── edge-site-2/gnb-monolithic-edge-site-2
└── lab-site/gnb-monolithic-lab-usrp
```

### OAI Split CU/DU Deployment

```
Management Cluster:
├── blueprints/cu-blueprint (upstream)
├── blueprints/du-blueprint (upstream)
├── PackageVariant: cu-regional-site
├── PackageVariant: cu-cloud-site
├── PackageVariant: du-edge-site-1
└── PackageVariant: du-edge-site-2

Workload Clusters:
├── regional-site/cu-regional-site (CU)
├── cloud-site/cu-cloud-site (CU)
├── edge-site-1/du-edge-site-1 (DU)
└── edge-site-2/du-edge-site-2 (DU)
```

## Deployment Workflow

### Phase 1: Setup Management Cluster

#### Step 1: Create IP Pools

```bash
# Create IP pools that will be used across all sites
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
---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: internal-pool
  namespace: default
spec:
  prefix: 10.0.0.0/24
  networkInstance:
    name: vpc-internal
---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: access-pool
  namespace: default
spec:
  prefix: 192.168.252.0/24
  networkInstance:
    name: vpc-ran
---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: core-pool
  namespace: default
spec:
  prefix: 192.168.250.0/24
  networkInstance:
    name: vpc-internet
EOF

# Verify
kubectl get ipprefixes
```

#### Step 2: Create Upstream Blueprints

```bash
# Register upstream blueprint repository
kubectl apply -f - <<EOF
apiVersion: config.porch.kpt.dev/v1alpha1
kind: Repository
metadata:
  name: blueprints
  namespace: default
spec:
  description: Upstream blueprints for SD-Core and OAI-RAN
  type: git
  content: Package
  git:
    repo: https://github.com/your-org/nephio-blueprints
    branch: main
    directory: /
EOF

# Verify
kubectl get repositories
```

#### Step 3: Create WorkloadCluster Resources

```bash
# Apply all WorkloadCluster definitions
kubectl apply -f sdcore-upf-packagevariants.yaml
kubectl apply -f oai-gnb-monolithic-packagevariants.yaml
kubectl apply -f oai-cu-du-split-packagevariants.yaml

# Or create them individually
kubectl apply -f - <<EOF
apiVersion: infra.nephio.org/v1alpha1
kind: WorkloadCluster
metadata:
  name: edge-site-1
  namespace: default
  labels:
    nephio.org/site: edge-site-1
    nephio.org/region: us-west
spec:
  clusterName: edge-site-1
  cnis:
  - macvlan
  - sriov
  masterInterface: ens3
EOF

# Verify
kubectl get workloadclusters
```

### Phase 2: Create PackageVariants

#### For SD-Core UPF

```bash
# Create PackageVariant for edge-site-1
kubectl apply -f - <<EOF
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: upf-edge-site-1
  namespace: default
  labels:
    nephio.org/site: edge-site-1
    nephio.org/network-function: upf
    nephio.org/vendor: sd-core
spec:
  upstream:
    repo: blueprints
    package: upf-blueprint
    revision: main
  downstream:
    repo: edge-site-1
    package: upf-edge-site-1
  adoptionPolicy: adoptExisting
  deletionPolicy: delete
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-site-1
  pipeline:
    mutators:
    - image: gcr.io/kpt-fn/set-labels:v0.2
      configMap:
        nephio.org/site: edge-site-1
        nephio.org/region: us-west
    - image: gcr.io/kpt-fn/apply-setters:v0.2
      configMap:
        site-name: edge-site-1
        cluster-name: edge-site-1
EOF

# Verify PackageVariant created
kubectl get packagevariants

# Watch package creation
kubectl get packagerevisions --watch
```

#### For OAI gNB Monolithic

```bash
# Create PackageVariant for edge-site-1
kubectl apply -f - <<EOF
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: gnb-monolithic-edge-site-1
  namespace: default
  labels:
    nephio.org/site: edge-site-1
    nephio.org/network-function: gnb
    nephio.org/vendor: oai
    nephio.org/deployment-type: monolithic
spec:
  upstream:
    repo: blueprints
    package: gnb-monolithic-blueprint
    revision: main
  downstream:
    repo: edge-site-1
    package: gnb-monolithic-edge-site-1
  adoptionPolicy: adoptExisting
  deletionPolicy: delete
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-site-1
  pipeline:
    mutators:
    - image: gcr.io/kpt-fn/set-labels:v0.2
      configMap:
        nephio.org/site: edge-site-1
        nephio.org/region: us-west
        nephio.org/deployment-type: monolithic
EOF
```

#### For OAI Split CU/DU

```bash
# Create CU PackageVariant for regional-site
kubectl apply -f - <<EOF
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: cu-regional-site
  namespace: default
  labels:
    nephio.org/site: regional-site
    nephio.org/network-function: cu
    nephio.org/vendor: oai
    nephio.org/deployment-type: split
spec:
  upstream:
    repo: blueprints
    package: cu-blueprint
    revision: main
  downstream:
    repo: regional-site
    package: cu-regional-site
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: regional-site
EOF

# Create DU PackageVariant for edge-site-1
kubectl apply -f - <<EOF
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: du-edge-site-1
  namespace: default
  labels:
    nephio.org/site: edge-site-1
    nephio.org/network-function: du
    nephio.org/vendor: oai
    nephio.org/deployment-type: split
spec:
  upstream:
    repo: blueprints
    package: du-blueprint
    revision: main
  downstream:
    repo: edge-site-1
    package: du-edge-site-1
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-site-1
EOF
```

### Phase 3: Monitor Package Creation

```bash
# List all PackageVariants
kubectl get packagevariants -A

# Check specific PackageVariant status
kubectl get packagevariant upf-edge-site-1 -o yaml

# List generated PackageRevisions
kubectl get packagerevisions -A

# Check package conditions
kubectl get packagerevision upf-edge-site-1-v1 -n upf -o jsonpath='{.status.conditions}' | jq .

# Watch package progression
watch kubectl get packagerevisions -A
```

Expected progression:
```
NAME                    LIFECYCLE   READY
upf-edge-site-1-v1     draft       False
upf-edge-site-1-v1     draft       False  # Interface processing
upf-edge-site-1-v1     draft       False  # IP allocation
upf-edge-site-1-v1     draft       True   # All conditions met
```

### Phase 4: Approve and Publish Packages

```bash
# Propose package
kpt alpha rpkg propose upf-edge-site-1-v1 -n upf

# Or via kubectl
kubectl patch packagerevision upf-edge-site-1-v1 -n upf \
  --type merge \
  -p '{"spec":{"lifecycle":"proposed"}}'

# Approve package
kpt alpha rpkg approve upf-edge-site-1-v1 -n upf

# Or via kubectl
kubectl patch packagerevision upf-edge-site-1-v1 -n upf \
  --type merge \
  -p '{"spec":{"lifecycle":"published"}}'

# Verify NADs deployed to workload cluster
kubectl config use-context edge-site-1
kubectl get network-attachment-definitions -n upf
kubectl get network-attachment-definitions -n oai-ran
```

## Batch Deployment Example

Deploy multiple sites at once:

```bash
# Deploy all SD-Core UPF PackageVariants
kubectl apply -f sdcore-upf-packagevariants.yaml

# Deploy all OAI gNB Monolithic PackageVariants
kubectl apply -f oai-gnb-monolithic-packagevariants.yaml

# Deploy all OAI CU/DU PackageVariants
kubectl apply -f oai-cu-du-split-packagevariants.yaml

# Watch all packages
watch kubectl get packagerevisions -A

# Once all packages are ready (conditions: True), approve them
for pkg in $(kubectl get packagerevisions -A -o jsonpath='{.items[?(@.status.conditions[?(@.type=="Ready" && @.status=="True")])].metadata.name}'); do
  echo "Approving $pkg"
  kpt alpha rpkg propose $pkg
  kpt alpha rpkg approve $pkg
done
```

## PackageVariant Customization

### Adding Site-Specific Configuration

You can add custom setters to apply site-specific values:

```yaml
apiVersion: porch.kpt.dev/v1alpha1
kind: PackageVariant
metadata:
  name: upf-edge-site-custom
spec:
  upstream:
    repo: blueprints
    package: upf-blueprint
    revision: main
  downstream:
    repo: edge-site-custom
    package: upf-edge-site-custom
  injectors:
  - name: workload-cluster
    kind: WorkloadCluster
    resourceName: edge-site-custom
  pipeline:
    mutators:
    # Apply custom labels
    - image: gcr.io/kpt-fn/set-labels:v0.2
      configMap:
        nephio.org/site: edge-site-custom
        nephio.org/region: us-west
        custom-label: custom-value
    
    # Apply custom setters (will replace placeholders in package)
    - image: gcr.io/kpt-fn/apply-setters:v0.2
      configMap:
        site-name: edge-site-custom
        cluster-name: edge-site-custom
        custom-interface: ens5
        custom-vlan: "500"
    
    # Apply custom annotations
    - image: gcr.io/kpt-fn/set-annotations:v0.1
      configMap:
        custom-annotation: custom-value
```

### Using Conditional Logic

Apply different configurations based on labels:

```yaml
pipeline:
  mutators:
  # Set different interface based on site type
  - image: gcr.io/kpt-fn/apply-setters:v0.2
    configMap:
      master-interface: |-
        {{ if eq .site "lab-site" }}ens4{{ else }}ens3{{ end }}
```

## Verification Checklist

### Management Cluster
- [ ] IP pools created (IPPrefix resources)
- [ ] WorkloadCluster resources created
- [ ] Blueprint repositories registered
- [ ] PackageVariants created
- [ ] PackageRevisions show Ready=True

### Per Site
```bash
# Check PackageRevision status
kubectl get packagerevision <site-package>-v1 -n <namespace> -o yaml

# Should see:
status:
  conditions:
  - type: config.injection.WorkloadCluster.workload-cluster
    status: "True"
  - type: req.nephio.org.interface.n2
    status: "True"
  - type: req.nephio.org.interface.n3
    status: "True"
  # ... all conditions True
  - type: Ready
    status: "True"
```

### Workload Cluster
```bash
# Switch to workload cluster
kubectl config use-context edge-site-1

# Check NADs deployed
kubectl get network-attachment-definitions -n upf
kubectl get network-attachment-definitions -n oai-ran

# Check NAD details
kubectl get network-attachment-definition n2 -n oai-ran -o yaml
```

## Troubleshooting

### PackageVariant Not Creating PackageRevision

```bash
# Check PackageVariant status
kubectl get packagevariant upf-edge-site-1 -o yaml

# Check if upstream package exists
kubectl get packagerevisions -A | grep upf-blueprint

# Check if downstream repo is registered
kubectl get repositories
```

### PackageRevision Stuck in Draft

```bash
# Check which condition is False
kubectl get packagerevision <name> -o jsonpath='{.status.conditions[?(@.status=="False")]}' | jq .

# Common issues:
# - WorkloadCluster not found
# - IP pool exhausted
# - Interface-fn or nad-fn not running
```

### NADs Not Deployed to Workload Cluster

```bash
# Check if package is published
kubectl get packagerevision <name> -o jsonpath='{.spec.lifecycle}'
# Should be: published

# Check ConfigSync status
kubectl get rootsync -A

# Check target cluster connectivity
kubectl config use-context <workload-cluster>
kubectl get pods -A
```

## Best Practices

1. **Naming Convention**: Use consistent naming: `{nf}-{site}-{variant}`
   - Example: `upf-edge-site-1`, `gnb-monolithic-lab`

2. **Labeling**: Apply consistent labels to all PackageVariants
   ```yaml
   labels:
     nephio.org/site: site-name
     nephio.org/network-function: upf|gnb|cu|du
     nephio.org/vendor: sd-core|oai
     nephio.org/deployment-type: monolithic|split
   ```

3. **Version Control**: Keep PackageVariant definitions in Git
   ```bash
   git add packagevariants/
   git commit -m "Add PackageVariant for edge-site-1"
   ```

4. **Testing**: Test PackageVariants in dev environment first
   ```bash
   # Create test PackageVariant
   kubectl apply -f packagevariant-test.yaml
   
   # Verify it works
   kubectl get packagerevisions | grep test
   
   # Delete after testing
   kubectl delete packagevariant test-variant
   ```

5. **Monitoring**: Set up alerts for PackageRevision failures
   ```bash
   # Monitor for packages stuck in draft
   kubectl get packagerevisions -A -o json | \
     jq '.items[] | select(.spec.lifecycle=="draft" and .status.conditions[]|select(.type=="Ready" and .status=="False"))'
   ```

## Summary: PackageVariants Created

### SD-Core UPF (3 variants)
- `upf-edge-site-1` - Edge deployment site 1
- `upf-edge-site-2` - Edge deployment site 2
- `upf-regional-site` - Regional deployment

### OAI gNB Monolithic (3 variants)
- `gnb-monolithic-edge-site-1` - Edge site 1
- `gnb-monolithic-edge-site-2` - Edge site 2
- `gnb-monolithic-lab-usrp` - Lab with USRP

### OAI Split CU (2 variants)
- `cu-regional-site` - Regional CU
- `cu-cloud-site` - Cloud CU

### OAI Split DU (3 variants)
- `du-edge-site-1` - Edge DU site 1
- `du-edge-site-2` - Edge DU site 2
- `du-lab-usrp` - Lab DU with USRP

**Total**: 11 PackageVariants across all architectures
