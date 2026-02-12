# Nephio Interface and IPClaim Guide for OAI gNB

## Overview

This guide explains how to create Nephio `Interface` and `IPClaim` resources for OAI gNB deployment. The Nephio NAD function will automatically generate NetworkAttachmentDefinitions based on these resources.

## OAI gNB Network Requirements

### Deployment Architectures

OAI supports two main architectures:

1. **Monolithic gNB**: All functions in one pod (CU + DU combined)
2. **Split CU/DU**: Separated Central Unit and Distributed Unit

## Nephio Resources for Monolithic gNB

### Complete Package Structure

```yaml
---
# interfaces.yaml
# Interface resources for OAI Monolithic gNB

apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n2
  namespace: oai-ran
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.gnb
  labels:
    nephio.org/interface: n2
    nephio.org/nf: gnb
    nephio.org/deployment-type: monolithic
spec:
  networkInstance:
    name: vpc-control
  cniType: macvlan
  attachmentType: vlan

---
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n3
  namespace: oai-ran
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.gnb
  labels:
    nephio.org/interface: n3
    nephio.org/nf: gnb
    nephio.org/deployment-type: monolithic
spec:
  networkInstance:
    name: vpc-userplane
  cniType: macvlan
  attachmentType: vlan

---
# Optional: RU interface for Ethernet-based USRP
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: ru
  namespace: oai-ran
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.gnb
  labels:
    nephio.org/interface: ru
    nephio.org/nf: gnb
    nephio.org/deployment-type: monolithic
spec:
  networkInstance:
    name: vpc-fronthaul
  cniType: macvlan
  attachmentType: vlan
```

### NetworkInstance Resources

```yaml
---
# network-instances.yaml

apiVersion: infra.nephio.org/v1alpha1
kind: NetworkInstance
metadata:
  name: vpc-control
  namespace: oai-ran
  annotations:
    config.kubernetes.io/local-config: "true"
  labels:
    nephio.org/network: control
spec:
  name: vpc-control
  interfaces:
  - kind: bridgedomain
  - kind: interface
    selector:
      matchLabels:
        nephio.org/interface: n2
  pools:
  - name: n2-ipv4-pool
    prefixLength: 24

---
apiVersion: infra.nephio.org/v1alpha1
kind: NetworkInstance
metadata:
  name: vpc-userplane
  namespace: oai-ran
  annotations:
    config.kubernetes.io/local-config: "true"
  labels:
    nephio.org/network: userplane
spec:
  name: vpc-userplane
  interfaces:
  - kind: bridgedomain
  - kind: interface
    selector:
      matchLabels:
        nephio.org/interface: n3
  pools:
  - name: n3-ipv4-pool
    prefixLength: 24

---
apiVersion: infra.nephio.org/v1alpha1
kind: NetworkInstance
metadata:
  name: vpc-fronthaul
  namespace: oai-ran
  annotations:
    config.kubernetes.io/local-config: "true"
  labels:
    nephio.org/network: fronthaul
spec:
  name: vpc-fronthaul
  interfaces:
  - kind: bridgedomain
  - kind: interface
    selector:
      matchLabels:
        nephio.org/interface: ru
  pools:
  - name: ru-ipv4-pool
    prefixLength: 24
```

## Nephio Resources for Split CU/DU

### CU (Central Unit) Interfaces

```yaml
---
# cu-interfaces.yaml

apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n2
  namespace: oai-cu
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.cu
  labels:
    nephio.org/interface: n2
    nephio.org/nf: cu
    nephio.org/deployment-type: split
spec:
  networkInstance:
    name: vpc-control
  cniType: macvlan
  attachmentType: vlan

---
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: f1c
  namespace: oai-cu
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.cu
  labels:
    nephio.org/interface: f1c
    nephio.org/nf: cu
    nephio.org/deployment-type: split
spec:
  networkInstance:
    name: vpc-midhaul
  cniType: macvlan
  attachmentType: vlan

---
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: e1
  namespace: oai-cu
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.cu
  labels:
    nephio.org/interface: e1
    nephio.org/nf: cu
    nephio.org/deployment-type: split
spec:
  networkInstance:
    name: vpc-cucp-cuup
  cniType: macvlan
  attachmentType: vlan
```

### DU (Distributed Unit) Interfaces

```yaml
---
# du-interfaces.yaml

apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: f1
  namespace: oai-du
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.du
  labels:
    nephio.org/interface: f1
    nephio.org/nf: du
    nephio.org/deployment-type: split
spec:
  networkInstance:
    name: vpc-midhaul
  cniType: macvlan
  attachmentType: vlan

---
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: n3
  namespace: oai-du
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.du
  labels:
    nephio.org/interface: n3
    nephio.org/nf: du
    nephio.org/deployment-type: split
spec:
  networkInstance:
    name: vpc-userplane
  cniType: macvlan
  attachmentType: vlan

---
apiVersion: req.nephio.org/v1alpha1
kind: Interface
metadata:
  name: ru
  namespace: oai-du
  annotations:
    config.kubernetes.io/local-config: "true"
    specializer.nephio.org/owner: req.nephio.org/v1alpha1.NFDeployment.du
  labels:
    nephio.org/interface: ru
    nephio.org/nf: du
    nephio.org/deployment-type: split
spec:
  networkInstance:
    name: vpc-fronthaul
  cniType: macvlan
  attachmentType: vlan
```

### Additional NetworkInstances for Split Architecture

```yaml
---
# split-network-instances.yaml

apiVersion: infra.nephio.org/v1alpha1
kind: NetworkInstance
metadata:
  name: vpc-midhaul
  namespace: oai-ran
  annotations:
    config.kubernetes.io/local-config: "true"
  labels:
    nephio.org/network: midhaul
spec:
  name: vpc-midhaul
  interfaces:
  - kind: bridgedomain
  - kind: interface
    selector:
      matchLabels:
        nephio.org/interface: f1c
  - kind: interface
    selector:
      matchLabels:
        nephio.org/interface: f1
  pools:
  - name: f1-ipv4-pool
    prefixLength: 24

---
apiVersion: infra.nephio.org/v1alpha1
kind: NetworkInstance
metadata:
  name: vpc-cucp-cuup
  namespace: oai-ran
  annotations:
    config.kubernetes.io/local-config: "true"
  labels:
    nephio.org/network: cucp-cuup
spec:
  name: vpc-cucp-cuup
  interfaces:
  - kind: bridgedomain
  - kind: interface
    selector:
      matchLabels:
        nephio.org/interface: e1
  pools:
  - name: e1-ipv4-pool
    prefixLength: 24
```

## IPPrefix Configuration (IP Pools)

Create IP pools in the management cluster:

```yaml
---
# ip-pools.yaml

apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: control-pool
  namespace: default
spec:
  prefix: 10.1.2.0/24
  networkInstance:
    name: vpc-control
  labels:
    nephio.org/purpose: control
    nephio.org/network-type: n2

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
  labels:
    nephio.org/purpose: userplane
    nephio.org/network-type: n3

---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: midhaul-pool
  namespace: default
spec:
  prefix: 10.2.5.0/24
  networkInstance:
    name: vpc-midhaul
  labels:
    nephio.org/purpose: midhaul
    nephio.org/network-type: f1

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
  labels:
    nephio.org/purpose: fronthaul
    nephio.org/network-type: ru

---
apiVersion: ipam.resource.nephio.org/v1alpha1
kind: IPPrefix
metadata:
  name: cucp-cuup-pool
  namespace: default
spec:
  prefix: 10.2.1.0/24
  networkInstance:
    name: vpc-cucp-cuup
  labels:
    nephio.org/purpose: cucp-cuup
    nephio.org/network-type: e1
```

## Kptfile Configuration

### For Monolithic gNB

```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: gnb-monolithic-blueprint
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: OAI gNB monolithic deployment package
  
  readinessGates:
  # WorkloadCluster injection
  - conditionType: config.injection.WorkloadCluster.workload-cluster
  
  # Interface processing (one per interface)
  - conditionType: req.nephio.org.interface.n2
  - conditionType: req.nephio.org.interface.n3
  - conditionType: req.nephio.org.interface.ru
  
  # IP allocation (one per interface)
  - conditionType: ipam.nephio.org.ipclaim.n2
  - conditionType: ipam.nephio.org.ipclaim.n3
  - conditionType: ipam.nephio.org.ipclaim.ru

pipeline:
  mutators:
  - image: docker.io/nephio/interface-fn:v2.0.0
    configMap:
      debug: "true"
  - image: docker.io/nephio/nad-fn:v2.0.0
    configMap:
      debug: "true"
  
  validators:
  - image: gcr.io/kpt-fn/kubeval:v0.3.0
    configMap:
      ignore_missing_schemas: "true"
```

### For Split CU

```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: cu-blueprint
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: OAI CU deployment package
  
  readinessGates:
  - conditionType: config.injection.WorkloadCluster.workload-cluster
  - conditionType: req.nephio.org.interface.n2
  - conditionType: req.nephio.org.interface.f1c
  - conditionType: req.nephio.org.interface.e1
  - conditionType: ipam.nephio.org.ipclaim.n2
  - conditionType: ipam.nephio.org.ipclaim.f1c
  - conditionType: ipam.nephio.org.ipclaim.e1

pipeline:
  mutators:
  - image: docker.io/nephio/interface-fn:v2.0.0
  - image: docker.io/nephio/nad-fn:v2.0.0
  
  validators:
  - image: gcr.io/kpt-fn/kubeval:v0.3.0
    configMap:
      ignore_missing_schemas: "true"
```

### For Split DU

```yaml
apiVersion: kpt.dev/v1
kind: Kptfile
metadata:
  name: du-blueprint
  annotations:
    config.kubernetes.io/local-config: "true"
info:
  description: OAI DU deployment package
  
  readinessGates:
  - conditionType: config.injection.WorkloadCluster.workload-cluster
  - conditionType: req.nephio.org.interface.f1
  - conditionType: req.nephio.org.interface.n3
  - conditionType: req.nephio.org.interface.ru
  - conditionType: ipam.nephio.org.ipclaim.f1
  - conditionType: ipam.nephio.org.ipclaim.n3
  - conditionType: ipam.nephio.org.ipclaim.ru

pipeline:
  mutators:
  - image: docker.io/nephio/interface-fn:v2.0.0
  - image: docker.io/nephio/nad-fn:v2.0.0
  
  validators:
  - image: gcr.io/kpt-fn/kubeval:v0.3.0
    configMap:
      ignore_missing_schemas: "true"
```

## WorkloadCluster Configuration

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

## Expected Generated NADs

After Nephio processes the package, NADs like these will be generated:

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: n2
  namespace: oai-ran
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "ens3",
      "mode": "bridge",
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "10.1.2.18/32",
            "gateway": "10.1.2.1"
          }
        ]
      }
    }
```

## Integration with OAI Helm Values

Once NADs are generated, update your OAI Helm values:

### Monolithic gNB

```yaml
# values.yaml
multus:
  defaultGateway: ""
  
  n2Interface:
    create: true
    ipAdd: "10.1.2.18"  # From IPClaim status
    netmask: "24"
    name: "n2"
    hostInterface: "ens3"
  
  n3Interface:
    create: true
    ipAdd: "10.1.3.18"  # From IPClaim status
    netmask: "24"
    name: "n3"
    hostInterface: "ens3"
  
  ruInterface:
    create: false
    ipAdd: "10.2.6.16"
    netmask: "24"
    name: "ru"
    mtu: 9000
    hostInterface: "ens4"

config:
  gnb:
    useAdditionalOptions: "--sa --log_config.global_log_options level,nocolor,time"
    amfIpAddress: "10.1.2.10"  # AMF N2 IP
    gtp:
      ipAddress: "10.1.3.18"  # gNB N3 IP
```

### Split CU

```yaml
# cu-values.yaml
multus:
  defaultGateway: ""
  
  n2Interface:
    create: true
    ipAdd: "10.1.2.18"
    netmask: "24"
    name: "n2"
    hostInterface: "ens3"
  
  f1cInterface:
    create: true
    ipAdd: "10.2.5.16"
    netmask: "24"
    name: "f1c"
    hostInterface: "ens3"
  
  e1Interface:
    create: true
    ipAdd: "10.2.1.16"
    netmask: "24"
    name: "e1"
    hostInterface: "ens3"
```

### Split DU

```yaml
# du-values.yaml
multus:
  defaultGateway: ""
  
  f1Interface:
    create: true
    ipAdd: "10.2.5.18"
    netmask: "24"
    name: "f1"
    hostInterface: "ens3"
  
  n3Interface:
    create: true
    ipAdd: "10.1.3.17"
    netmask: "24"
    name: "n3"
    hostInterface: "ens3"
  
  ruInterface:
    create: false
    ipAdd: "10.2.6.16"
    netmask: "24"
    name: "ru"
    mtu: 9000
    hostInterface: "ens4"

config:
  du:
    localN:
      address: "10.2.5.18"  # DU F1 local address
    remoteN:
      address: "10.2.5.16"  # CU F1 address
```

## Summary: Interface Count by Architecture

### Monolithic gNB
- **Minimum**: 2 interfaces (N2, N3)
- **With USRP**: 3 interfaces (N2, N3, RU)
- **Readiness Gates**: 7 (1 WorkloadCluster + 3 Interface + 3 IPClaim)

### Split CU
- **Required**: 3 interfaces (N2, F1-C, E1)
- **Readiness Gates**: 7 (1 WorkloadCluster + 3 Interface + 3 IPClaim)

### Split DU
- **Minimum**: 2 interfaces (F1, N3)
- **With USRP**: 3 interfaces (F1, N3, RU)
- **Readiness Gates**: 7 (1 WorkloadCluster + 3 Interface + 3 IPClaim)

## Best Practices

1. **Namespace Separation**: Use separate namespaces for CU and DU
2. **Labeling**: Use consistent labels for filtering and selection
3. **IP Planning**: Reserve IP blocks for each interface type
4. **Documentation**: Document IP allocations and dependencies
5. **Testing**: Test each architecture separately before combining

## References

- [OAI GitLab](https://gitlab.eurecom.fr/oai/openairinterface5g)
- [OAI Operators](https://github.com/OPENAIRINTERFACE/oai-operators)
- [Nephio Documentation](https://nephio.org/docs/)
- [3GPP TS 38.401](https://www.3gpp.org/DynaReport/38401.htm)
