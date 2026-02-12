# OAI-RAN NetworkAttachmentDefinition (NAD) Guide

## Overview

This guide explains the network requirements for deploying OpenAirInterface (OAI) gNB (gNodeB) on Kubernetes using Multus CNI and NetworkAttachmentDefinitions. OAI gNB requires multiple network interfaces for different 5G protocols.

## OAI gNB Architecture

### Network Interfaces Required

OAI gNB supports both **monolithic** and **split** (CU/DU) architectures:

#### 1. Monolithic gNB

```
┌────────────────────────────────────┐
│        Monolithic gNB Pod          │
│                                    │
│  ┌──────────────────────────────┐ │
│  │         gNB Stack            │ │
│  │   (CU + DU functions)        │ │
│  └──────────────────────────────┘ │
│                                    │
│  Network Interfaces:               │
│  - eth0: Default K8s network       │
│  - N2: Control plane to AMF        │
│  - N3: User plane to UPF           │
│  - (Optional) RU: To Radio Unit    │
└────────────────────────────────────┘
         │            │
         │ N2         │ N3
         │ (NGAP)     │ (GTP-U)
         ▼            ▼
    ┌────────┐   ┌────────┐
    │  AMF   │   │  UPF   │
    └────────┘   └────────┘
```

#### 2. Split gNB (CU/DU)

```
┌─────────────────────────────────────────────────┐
│               CU Pod (Central Unit)              │
│                                                  │
│  Network Interfaces:                             │
│  - eth0: Default K8s network                     │
│  - N2: Control plane to AMF                      │
│  - F1-C: Control plane to DU (F1 interface)      │
│  - E1: Between CU-CP and CU-UP                   │
└─────────────────────────────────────────────────┘
         │            │
         │ N2         │ F1-C
         │ (NGAP)     │ (F1AP)
         ▼            ▼
    ┌────────┐   ┌─────────────────────────────┐
    │  AMF   │   │      DU Pod (Distributed)    │
    └────────┘   │                              │
                 │  Network Interfaces:          │
                 │  - eth0: Default K8s network  │
                 │  - F1-C: Control to CU        │
                 │  - F1-U: User plane to CU     │
                 │  - RU: To Radio Unit (USRP)   │
                 └──────────────────────────────┘
                          │
                          │ RU (Ethernet or USRP)
                          ▼
                   ┌─────────────┐
                   │ Radio Unit  │
                   │   (USRP)    │
                   └─────────────┘
```

## Network Interface Details

### For Monolithic gNB

| Interface | 5G Name | Purpose | Protocol | Typical Subnet |
|-----------|---------|---------|----------|----------------|
| N2 | N2 | Control plane to AMF | NGAP/SCTP | 10.1.2.0/24 |
| N3 | N3 | User plane to UPF | GTP-U | 10.1.3.0/24 |
| RU | - | To Radio Unit (Optional) | Ethernet/USRP | 10.2.6.0/24 |

### For Split CU/DU

**CU (Central Unit)**:
| Interface | Purpose | Protocol | Typical Subnet |
|-----------|---------|----------|----------------|
| N2 | Control to AMF | NGAP/SCTP | 10.1.2.0/24 |
| F1-C | F1 Control to DU | F1AP | 10.2.5.0/24 |
| E1 | CU-CP to CU-UP | E1AP | 10.2.1.0/24 |

**DU (Distributed Unit)**:
| Interface | Purpose | Protocol | Typical Subnet |
|-----------|---------|----------|----------------|
| F1-C | F1 Control to CU | F1AP | 10.2.5.0/24 |
| F1-U | F1 User plane to CU | GTP-U | 10.2.5.0/24 |
| N3 | User plane to UPF | GTP-U | 10.1.3.0/24 |
| RU | To Radio Unit | Ethernet/USRP | 10.2.6.0/24 |

## Prerequisites

### 1. Install Multus CNI

```bash
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml

# Verify
kubectl get pods -n kube-system | grep multus
kubectl get crd | grep network-attachment
```

### 2. Install CNI Plugins

```bash
# On each node
wget https://github.com/containernetworking/plugins/releases/download/v1.3.0/cni-plugins-linux-amd64-v1.3.0.tgz
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf cni-plugins-linux-amd64-v1.3.0.tgz
```

## Creating NADs for OAI gNB

### Scenario 1: Monolithic gNB

#### NAD for N2 Interface (Control Plane to AMF)

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: gnb-n2
  namespace: oai-ran
  labels:
    app: oai-gnb
    interface: n2
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
            "address": "10.1.2.18/24",
            "gateway": "10.1.2.1"
          }
        ],
        "routes": [
          {
            "dst": "10.1.2.0/24"
          }
        ]
      }
    }
```

#### NAD for N3 Interface (User Plane to UPF)

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: gnb-n3
  namespace: oai-ran
  labels:
    app: oai-gnb
    interface: n3
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
            "address": "10.1.3.18/24",
            "gateway": "10.1.3.1"
          }
        ],
        "routes": [
          {
            "dst": "0.0.0.0/0"
          }
        ]
      }
    }
```

#### NAD for RU Interface (Optional - for Ethernet-based RU/USRP)

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: gnb-ru
  namespace: oai-ran
  labels:
    app: oai-gnb
    interface: ru
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "ens4",
      "mode": "bridge",
      "mtu": 9000,
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "10.2.6.16/24",
            "gateway": "10.2.6.1"
          }
        ]
      }
    }
```

### Scenario 2: Split CU/DU

#### CU NADs

**CU N2 Interface**:
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: cu-n2
  namespace: oai-ran
  labels:
    app: oai-cu
    interface: n2
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
            "address": "10.1.2.18/24",
            "gateway": "10.1.2.1"
          }
        ]
      }
    }
```

**CU F1-C Interface**:
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: cu-f1c
  namespace: oai-ran
  labels:
    app: oai-cu
    interface: f1c
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
            "address": "10.2.5.16/24",
            "gateway": "10.2.5.1"
          }
        ]
      }
    }
```

**CU E1 Interface**:
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: cu-e1
  namespace: oai-ran
  labels:
    app: oai-cu
    interface: e1
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
            "address": "10.2.1.16/24",
            "gateway": "10.2.1.1"
          }
        ]
      }
    }
```

#### DU NADs

**DU F1 Interface** (combined F1-C and F1-U):
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: du-f1
  namespace: oai-ran
  labels:
    app: oai-du
    interface: f1
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
            "address": "10.2.5.18/24",
            "gateway": "10.2.5.1"
          }
        ]
      }
    }
```

**DU N3 Interface**:
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: du-n3
  namespace: oai-ran
  labels:
    app: oai-du
    interface: n3
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
            "address": "10.1.3.17/24",
            "gateway": "10.1.3.1"
          }
        ]
      }
    }
```

**DU RU Interface**:
```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: du-ru
  namespace: oai-ran
  labels:
    app: oai-du
    interface: ru
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "macvlan",
      "master": "ens4",
      "mode": "bridge",
      "mtu": 9000,
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "10.2.6.16/24",
            "gateway": "10.2.6.1"
          }
        ]
      }
    }
```

## Integration with OAI Helm Charts

### Monolithic gNB Values

Based on the OAI Helm charts, here's how to reference NADs:

```yaml
# values.yaml for oai-gnb
multus:
  defaultGateway: ""
  
  n2Interface:
    create: true
    ipAdd: "10.1.2.18"
    netmask: "24"
    name: "n2"
    hostInterface: "ens3"
  
  n3Interface:
    create: true
    ipAdd: "10.1.3.18"
    netmask: "24"
    name: "n3"
    hostInterface: "ens3"
  
  ruInterface:
    create: false  # Set to true if using Ethernet RU
    ipAdd: "10.2.6.16"
    netmask: "24"
    name: "ru"
    mtu: 9000
    hostInterface: "ens4"
```

### Split CU Configuration

```yaml
# values.yaml for oai-cu
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

### Split DU Configuration

```yaml
# values.yaml for oai-du
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
```

## Verification

### Check NADs

```bash
kubectl get network-attachment-definitions -n oai-ran
```

### Check gNB Pod Interfaces

```bash
# For monolithic gNB
kubectl exec -it -n oai-ran <gnb-pod> -- ip addr

# Should see:
# eth0 - default
# net1 - n2 interface (10.1.2.18)
# net2 - n3 interface (10.1.3.18)
# net3 - ru interface (if configured)
```

### Test Connectivity

```bash
# Test N2 to AMF
kubectl exec -it -n oai-ran <gnb-pod> -- ping 10.1.2.10

# Test N3 to UPF
kubectl exec -it -n oai-ran <gnb-pod> -- ping 10.1.3.3
```

## Common Deployment Scenarios

### 1. RF Simulator Mode (No Real Radio)

Uses only N2 and N3 interfaces. No RU interface needed.

```yaml
# Minimal NADs required
- gnb-n2
- gnb-n3
```

### 2. With USRP (Ethernet-based)

Requires RU interface for USRP connectivity.

```yaml
# All NADs required
- gnb-n2
- gnb-n3
- gnb-ru (with MTU 9000)
```

### 3. Split Architecture

Full disaggregated deployment.

```yaml
# CU NADs
- cu-n2
- cu-f1c
- cu-e1

# DU NADs
- du-f1
- du-n3
- du-ru
```

## Troubleshooting

### Issue: Interfaces Not Created

```bash
# Check Multus logs
kubectl logs -n kube-system <multus-pod>

# Verify NAD exists
kubectl describe network-attachment-definition gnb-n2 -n oai-ran
```

### Issue: Cannot Ping AMF

```bash
# Check routes
kubectl exec -it -n oai-ran <gnb-pod> -- ip route

# Check if AMF is reachable from host
ping 10.1.2.10
```

### Issue: NGAP Connection Failed

```bash
# Check gNB logs
kubectl logs -n oai-ran <gnb-pod>

# Look for SCTP establishment messages
# Should see: "SCTP connection established"
```

## Best Practices

1. **Use Separate VLANs**: Isolate N2, N3, and F1 traffic
2. **MTU Settings**: Use MTU 9000 for RU interface if using USRP
3. **IP Planning**: Reserve IP ranges for each interface type
4. **Labeling**: Use consistent labels for easier management
5. **Documentation**: Document IP allocations and interface mappings

## References

- [OAI gNB Documentation](https://gitlab.eurecom.fr/oai/openairinterface5g)
- [OAI Operators GitHub](https://github.com/OPENAIRINTERFACE/oai-operators)
- [Multus CNI](https://github.com/k8snetworkplumbingwg/multus-cni)
- [3GPP TS 38.401](https://www.3gpp.org/DynaReport/38401.htm) - NG-RAN Architecture
