# OAI gNB Single-Node Cluster Deployment Topology

## Overview: Your Single-Node Edge Cluster

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         SINGLE NODE CLUSTER                                  │
│                         (Edge Site - Running OAI gNB)                        │
│                                                                              │
│  Physical Server: edge-node-1                                               │
│  OS: Ubuntu 24.04                                                           │
│  Kubernetes: v1.28+                                                         │
│  Physical NICs: ens3 (main), ens4 (optional for RU)                        │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Detailed Pod and Interface Topology

```
┌──────────────────────────────────────────────────────────────────────────────────────────┐
│                              SINGLE NODE: edge-node-1                                     │
│                                                                                           │
│  ┌────────────────────────────────────────────────────────────────────────────────┐     │
│  │                         Namespace: kube-system                                  │     │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌──────────────────┐              │     │
│  │  │  multus         │  │  calico-node    │  │  kube-proxy      │              │     │
│  │  │  DaemonSet      │  │  DaemonSet      │  │  DaemonSet       │              │     │
│  │  │                 │  │                 │  │                  │              │     │
│  │  │  Pod: multus-xxx│  │  Pod: calico-xxx│  │  Pod: proxy-xxx  │              │     │
│  │  │  eth0 only      │  │  eth0 only      │  │  eth0 only       │              │     │
│  │  └─────────────────┘  └─────────────────┘  └──────────────────┘              │     │
│  └────────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                           │
│  ┌────────────────────────────────────────────────────────────────────────────────┐     │
│  │                    Namespace: oai-ran-operators                                 │     │
│  │  ┌──────────────────────────────────────────────────────────────────────┐     │     │
│  │  │  OAI RAN Operator                                                     │     │     │
│  │  │  Deployment: oai-ran-operator                                         │     │     │
│  │  │                                                                        │     │     │
│  │  │  Pod: oai-ran-operator-xxxxxxxxxx-xxxxx                               │     │     │
│  │  │  ┌──────────────────────────────────────────────────────────┐        │     │     │
│  │  │  │  Container: manager                                       │        │     │     │
│  │  │  │                                                            │        │     │     │
│  │  │  │  Watches:                                                 │        │     │     │
│  │  │  │  - NFDeployment CRs                                       │        │     │     │
│  │  │  │  - NFConfig CRs                                           │        │     │     │
│  │  │  │                                                            │        │     │     │
│  │  │  │  Creates:                                                 │        │     │     │
│  │  │  │  - gNB Deployment/StatefulSet                            │        │     │     │
│  │  │  │  - ConfigMaps                                             │        │     │     │
│  │  │  │  - Services                                               │        │     │     │
│  │  │  │                                                            │        │     │     │
│  │  │  │  Network:                                                 │        │     │     │
│  │  │  │  eth0: 10.244.0.15 (Primary - Calico)                    │        │     │     │
│  │  │  └──────────────────────────────────────────────────────────┘        │     │     │
│  │  └──────────────────────────────────────────────────────────────────────┘     │     │
│  └────────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                           │
│  ┌────────────────────────────────────────────────────────────────────────────────┐     │
│  │                         Namespace: oai-ran                                      │     │
│  │                                                                                 │     │
│  │  ┌───────────────────────────────────────────────────────────────────────┐    │     │
│  │  │  OAI gNB (Monolithic)                                                  │    │     │
│  │  │  StatefulSet: oai-gnb                                                  │    │     │
│  │  │                                                                         │    │     │
│  │  │  Pod: oai-gnb-0                                                        │    │     │
│  │  │  ┌──────────────────────────────────────────────────────────────┐    │    │     │
│  │  │  │  Container: gnb                                               │    │    │     │
│  │  │  │  Image: oaisoftwarealliance/oai-gnb:latest                   │    │    │     │
│  │  │  │                                                               │    │    │     │
│  │  │  │  ┌─────────────────────────────────────────────────────┐    │    │    │     │
│  │  │  │  │  INTERFACES:                                         │    │    │    │     │
│  │  │  │  │                                                       │    │    │    │     │
│  │  │  │  │  eth0 (PRIMARY - Calico CNI)                        │    │    │    │     │
│  │  │  │  │  ├─ IP: 10.244.0.20/24                              │    │    │    │     │
│  │  │  │  │  ├─ Gateway: 10.244.0.1                             │    │    │    │     │
│  │  │  │  │  ├─ DNS: 10.96.0.10                                 │    │    │    │     │
│  │  │  │  │  └─ Used for: K8s cluster communication,           │    │    │    │     │
│  │  │  │  │               Metrics, Health checks,               │    │    │    │     │
│  │  │  │  │               Internal services                     │    │    │    │     │
│  │  │  │  │                                                       │    │    │    │     │
│  │  │  │  │  net1 (SECONDARY - N2 Interface)                    │    │    │    │     │
│  │  │  │  │  ├─ NAD: n2 (oai-ran namespace)                     │    │    │    │     │
│  │  │  │  │  ├─ Type: macvlan (master: ens3)                    │    │    │    │     │
│  │  │  │  │  ├─ IP: 10.1.2.20/24 (from IPClaim)                │    │    │    │     │
│  │  │  │  │  ├─ Gateway: 10.1.2.1                               │    │    │    │     │
│  │  │  │  │  ├─ VLAN: 102 (optional)                            │    │    │    │     │
│  │  │  │  │  └─ Used for: NGAP (Control to AMF)                │    │    │    │     │
│  │  │  │  │                                                       │    │    │    │     │
│  │  │  │  │  net2 (SECONDARY - N3 Interface)                    │    │    │    │     │
│  │  │  │  │  ├─ NAD: n3 (oai-ran namespace)                     │    │    │    │     │
│  │  │  │  │  ├─ Type: macvlan (master: ens3)                    │    │    │    │     │
│  │  │  │  │  ├─ IP: 10.1.3.20/24 (from IPClaim)                │    │    │    │     │
│  │  │  │  │  ├─ Gateway: 10.1.3.1                               │    │    │    │     │
│  │  │  │  │  ├─ VLAN: 103 (optional)                            │    │    │    │     │
│  │  │  │  │  └─ Used for: GTP-U (User Plane to UPF)            │    │    │    │     │
│  │  │  │  │                                                       │    │    │    │     │
│  │  │  │  │  net3 (SECONDARY - RU Interface - Optional)         │    │    │    │     │
│  │  │  │  │  ├─ NAD: ru (oai-ran namespace)                     │    │    │    │     │
│  │  │  │  │  ├─ Type: macvlan (master: ens4)                    │    │    │    │     │
│  │  │  │  │  ├─ IP: 10.2.6.20/24 (from IPClaim)                │    │    │    │     │
│  │  │  │  │  ├─ Gateway: 10.2.6.1                               │    │    │    │     │
│  │  │  │  │  ├─ MTU: 9000 (Jumbo frames)                        │    │    │    │     │
│  │  │  │  │  └─ Used for: Fronthaul to USRP/RU                 │    │    │    │     │
│  │  │  │  └─────────────────────────────────────────────────────┘    │    │    │     │
│  │  │  │                                                               │    │    │     │
│  │  │  │  Process: nr-softmodem                                       │    │    │     │
│  │  │  │  Config: /opt/oai-gnb/etc/gnb.conf                          │    │    │     │
│  │  │  │  Logs: /opt/oai-gnb/log/gnb.log                             │    │    │     │
│  │  │  │                                                               │    │    │     │
│  │  │  │  Resources:                                                   │    │    │     │
│  │  │  │  - CPU: 2 cores (request), 4 cores (limit)                  │    │    │     │
│  │  │  │  - Memory: 4Gi (request), 8Gi (limit)                       │    │    │     │
│  │  │  │  - Huge Pages: 1Gi (optional for DPDK)                      │    │    │     │
│  │  │  └──────────────────────────────────────────────────────────────┘    │    │     │
│  │  └───────────────────────────────────────────────────────────────────────┘    │     │
│  │                                                                                 │     │
│  │  Supporting Resources:                                                          │     │
│  │  ┌─────────────────────────────────────────────────────────────────┐          │     │
│  │  │  ConfigMap: oai-gnb-config                                       │          │     │
│  │  │  - gnb.conf (OAI gNB configuration)                             │          │     │
│  │  │  - Contains: MCC, MNC, TAC, PLMN, AMF address, etc.            │          │     │
│  │  └─────────────────────────────────────────────────────────────────┘          │     │
│  │                                                                                 │     │
│  │  ┌─────────────────────────────────────────────────────────────────┐          │     │
│  │  │  Service: oai-gnb-service                                        │          │     │
│  │  │  Type: ClusterIP                                                 │          │     │
│  │  │  Ports:                                                           │          │     │
│  │  │  - 38472 (F1-C - if split mode)                                 │          │     │
│  │  │  - 2152 (GTP-U - monitoring)                                    │          │     │
│  │  └─────────────────────────────────────────────────────────────────┘          │     │
│  │                                                                                 │     │
│  │  ┌─────────────────────────────────────────────────────────────────┐          │     │
│  │  │  NetworkAttachmentDefinition: n2                                 │          │     │
│  │  │  - Generated by nad-fn                                           │          │     │
│  │  │  - References: ens3, macvlan, static IPAM                       │          │     │
│  │  └─────────────────────────────────────────────────────────────────┘          │     │
│  │                                                                                 │     │
│  │  ┌─────────────────────────────────────────────────────────────────┐          │     │
│  │  │  NetworkAttachmentDefinition: n3                                 │          │     │
│  │  │  - Generated by nad-fn                                           │          │     │
│  │  │  - References: ens3, macvlan, static IPAM                       │          │     │
│  │  └─────────────────────────────────────────────────────────────────┘          │     │
│  │                                                                                 │     │
│  │  ┌─────────────────────────────────────────────────────────────────┐          │     │
│  │  │  NetworkAttachmentDefinition: ru                                 │          │     │
│  │  │  - Generated by nad-fn                                           │          │     │
│  │  │  - References: ens4, macvlan, static IPAM, MTU 9000             │          │     │
│  │  └─────────────────────────────────────────────────────────────────┘          │     │
│  └────────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                           │
│  ┌────────────────────────────────────────────────────────────────────────────────┐     │
│  │                      Physical Network Interfaces                                │     │
│  │  ┌──────────────────────────────────────────────────────────────────────┐     │     │
│  │  │  ens3 (Primary Physical NIC)                                          │     │     │
│  │  │  ├─ State: UP                                                         │     │     │
│  │  │  ├─ Promisc: ON (for MacVLAN)                                        │     │     │
│  │  │  ├─ Master for:                                                       │     │     │
│  │  │  │  ├─ net1 (N2 interface) - VLAN 102                               │     │     │
│  │  │  │  └─ net2 (N3 interface) - VLAN 103                               │     │     │
│  │  │  ├─ Connected to: Network switch                                     │     │     │
│  │  │  └─ Speed: 10 Gbps                                                   │     │     │
│  │  └──────────────────────────────────────────────────────────────────────┘     │     │
│  │                                                                                 │     │
│  │  ┌──────────────────────────────────────────────────────────────────────┐     │     │
│  │  │  ens4 (Secondary Physical NIC - Optional for RU)                     │     │     │
│  │  │  ├─ State: UP                                                         │     │     │
│  │  │  ├─ Promisc: ON (for MacVLAN)                                        │     │     │
│  │  │  ├─ MTU: 9000 (Jumbo frames)                                         │     │     │
│  │  │  ├─ Master for:                                                       │     │     │
│  │  │  │  └─ net3 (RU interface)                                           │     │     │
│  │  │  ├─ Connected to: USRP B210                                          │     │     │
│  │  │  └─ Speed: 1 Gbps                                                    │     │     │
│  │  └──────────────────────────────────────────────────────────────────────┘     │     │
│  └────────────────────────────────────────────────────────────────────────────────┘     │
│                                                                                           │
│  ┌────────────────────────────────────────────────────────────────────────────────┐     │
│  │                         SR-IOV Alternative (If Used)                            │     │
│  │  ┌──────────────────────────────────────────────────────────────────────┐     │     │
│  │  │  Intel E810 NIC (Physical Function)                                   │     │     │
│  │  │  ├─ PF: ens3                                                          │     │     │
│  │  │  ├─ VFs created: 4                                                    │     │     │
│  │  │  │  ├─ VF 0 → net1 (N2) in gNB pod                                  │     │     │
│  │  │  │  ├─ VF 1 → net2 (N3) in gNB pod                                  │     │     │
│  │  │  │  ├─ VF 2 → Available                                              │     │     │
│  │  │  │  └─ VF 3 → Available                                              │     │     │
│  │  │  └─ Hardware switch forwards between VFs                             │     │     │
│  │  └──────────────────────────────────────────────────────────────────────┘     │     │
│  └────────────────────────────────────────────────────────────────────────────────┘     │
└──────────────────────────────────────────────────────────────────────────────────────────┘

External Connections (from this single node):
                        │                    │                    │
                        │ N2                 │ N3                 │ RU
                        │ 10.1.2.0/24        │ 10.1.3.0/24        │ 10.2.6.0/24
                        ▼                    ▼                    ▼
                   ┌─────────┐          ┌─────────┐         ┌──────────┐
                   │   AMF   │          │   UPF   │         │  USRP    │
                   │(Core DC)│          │(Core DC)│         │  B210    │
                   └─────────┘          └─────────┘         └──────────┘
```

## Network Flow Visualization

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                    Traffic Flow on Single Node                                │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  Control Plane (N2 - NGAP/SCTP):                                            │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  gNB Pod                                                         │        │
│  │  └─ net1 (10.1.2.20) ──┐                                        │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    MacVLAN on ens3                               │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    ens3 (Physical NIC)                           │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    Network Switch                                │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    AMF (10.1.2.10)                               │        │
│  │                    [Different Cluster/DC]                        │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                               │
│  User Plane (N3 - GTP-U):                                                   │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  gNB Pod                                                         │        │
│  │  └─ net2 (10.1.3.20) ──┐                                        │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    MacVLAN on ens3                               │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    ens3 (Physical NIC)                           │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    Network Switch                                │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    UPF (10.1.3.3)                                │        │
│  │                    [Different Cluster/DC]                        │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                               │
│  Fronthaul (RU - Ethernet/eCPRI):                                           │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  gNB Pod                                                         │        │
│  │  └─ net3 (10.2.6.20) ──┐                                        │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    MacVLAN on ens4                               │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    ens4 (Physical NIC)                           │        │
│  │                         │                                        │        │
│  │                         ▼                                        │        │
│  │                    USRP B210                                     │        │
│  │                    [Directly Connected]                          │        │
│  └─────────────────────────────────────────────────────────────────┘        │
│                                                                               │
│  Internal/Management (eth0 - Calico):                                       │
│  ┌─────────────────────────────────────────────────────────────────┐        │
│  │  gNB Pod                                                         │        │
│  │  └─ eth0 (10.244.0.20) ──┐                                      │        │
│  │                           │                                      │        │
│  │                           ▼                                      │        │
│  │                      Calico vRouter                              │        │
│  │                           │                                      │        │
│  │                           ▼                                      │        │
│  │                      Internal Pod Network                        │        │
│  │                           │                                      │        │
│  │                           ├──> Metrics Server                    │        │
│  │                           ├──> Logging (Fluentd)                │        │
│  │                           ├──> Health Checks                     │        │
│  │                           └──> Operator Communications           │        │
│  └─────────────────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────────────────┘
```

## Pod Interface Details

```
┌─────────────────────────────────────────────────────────────────────────┐
│                     gNB Pod Interface Summary                            │
├──────────────┬─────────────┬─────────────┬─────────────┬───────────────┤
│ Interface    │ Network     │ IP Address  │ Gateway     │ Purpose       │
├──────────────┼─────────────┼─────────────┼─────────────┼───────────────┤
│ eth0         │ Calico      │ 10.244.0.20 │ 10.244.0.1  │ K8s Internal  │
│ (PRIMARY)    │ (K8s CNI)   │             │             │ Management    │
│              │             │             │             │ Metrics       │
│              │             │             │             │ Health        │
├──────────────┼─────────────┼─────────────┼─────────────┼───────────────┤
│ net1         │ N2          │ 10.1.2.20   │ 10.1.2.1    │ NGAP to AMF   │
│ (SECONDARY)  │ MacVLAN     │             │             │ Control Plane │
│              │ NAD: n2     │             │             │ SCTP/38412    │
├──────────────┼─────────────┼─────────────┼─────────────┼───────────────┤
│ net2         │ N3          │ 10.1.3.20   │ 10.1.3.1    │ GTP-U to UPF  │
│ (SECONDARY)  │ MacVLAN     │             │             │ User Plane    │
│              │ NAD: n3     │             │             │ UDP/2152      │
├──────────────┼─────────────┼─────────────┼─────────────┼───────────────┤
│ net3         │ RU          │ 10.2.6.20   │ 10.2.6.1    │ Fronthaul     │
│ (SECONDARY)  │ MacVLAN     │             │             │ To USRP/RU    │
│ (Optional)   │ NAD: ru     │             │             │ Ethernet      │
│              │ MTU: 9000   │             │             │ eCPRI         │
└──────────────┴─────────────┴─────────────┴─────────────┴───────────────┘
```

## Nephio Resources on Management Cluster

```
┌──────────────────────────────────────────────────────────────────────────┐
│                    MANAGEMENT CLUSTER (Separate)                          │
│                                                                           │
│  IPPrefix Resources (IP Pools):                                          │
│  ┌─────────────────────────────────────────────────────────────┐        │
│  │ apiVersion: ipam.resource.nephio.org/v1alpha1              │        │
│  │ kind: IPPrefix                                              │        │
│  │ metadata:                                                   │        │
│  │   name: control-pool                                        │        │
│  │ spec:                                                       │        │
│  │   prefix: 10.1.2.0/24                                      │        │
│  │   networkInstance:                                          │        │
│  │     name: vpc-control                                       │        │
│  └─────────────────────────────────────────────────────────────┘        │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐        │
│  │ apiVersion: ipam.resource.nephio.org/v1alpha1              │        │
│  │ kind: IPPrefix                                              │        │
│  │ metadata:                                                   │        │
│  │   name: userplane-pool                                      │        │
│  │ spec:                                                       │        │
│  │   prefix: 10.1.3.0/24                                      │        │
│  │   networkInstance:                                          │        │
│  │     name: vpc-userplane                                     │        │
│  └─────────────────────────────────────────────────────────────┘        │
│                                                                           │
│  ┌─────────────────────────────────────────────────────────────┐        │
│  │ apiVersion: ipam.resource.nephio.org/v1alpha1              │        │
│  │ kind: IPPrefix                                              │        │
│  │ metadata:                                                   │        │
│  │   name: fronthaul-pool                                      │        │
│  │ spec:                                                       │        │
│  │   prefix: 10.2.6.0/24                                      │        │
│  │   networkInstance:                                          │        │
│  │     name: vpc-fronthaul                                     │        │
│  └─────────────────────────────────────────────────────────────┘        │
│                                                                           │
│  WorkloadCluster:                                                         │
│  ┌─────────────────────────────────────────────────────────────┐        │
│  │ apiVersion: infra.nephio.org/v1alpha1                       │        │
│  │ kind: WorkloadCluster                                       │        │
│  │ metadata:                                                   │        │
│  │   name: edge-cluster-1                                      │        │
│  │ spec:                                                       │        │
│  │   clusterName: edge-cluster-1                              │        │
│  │   cnis:                                                     │        │
│  │   - macvlan                                                 │        │
│  │   - sriov                                                   │        │
│  │   masterInterface: ens3                                     │        │
│  └─────────────────────────────────────────────────────────────┘        │
│                                                                           │
│  Package (in Porch):                                                      │
│  ┌─────────────────────────────────────────────────────────────┐        │
│  │ PackageRevision: oai-gnb-edge1-v1                           │        │
│  │ Status:                                                     │        │
│  │   conditions:                                               │        │
│  │   - type: req.nephio.org.interface.n2                      │        │
│  │     status: "True"                                          │        │
│  │   - type: req.nephio.org.interface.n3                      │        │
│  │     status: "True"                                          │        │
│  │   - type: req.nephio.org.interface.ru                      │        │
│  │     status: "True"                                          │        │
│  │   - type: ipam.nephio.org.ipclaim.n2                       │        │
│  │     status: "True"                                          │        │
│  │   - type: ipam.nephio.org.ipclaim.n3                       │        │
│  │     status: "True"                                          │        │
│  │   - type: ipam.nephio.org.ipclaim.ru                       │        │
│  │     status: "True"                                          │        │
│  │   - type: Ready                                             │        │
│  │     status: "True"                                          │        │
│  └─────────────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────────────┘
```

## Resource Hierarchy

```
Management Cluster
└── PackageRevision: oai-gnb-edge1-v1
    ├── Interface: n2 ──────┐
    ├── Interface: n3 ──────┼──> Creates ──> IPClaim: n2
    ├── Interface: ru ──────┘              IPClaim: n3
    │                                       IPClaim: ru
    │                                            │
    │                                            ▼
    │                                   Nephio IPAM Controller
    │                                            │
    │                                            ▼
    │                                   Allocates from IPPrefix
    │                                            │
    │                                            ▼
    │                                   Updates IPClaim.status
    │                                            │
    │                                            ▼
    └──> nad-fn ◄──────────────────────── Reads IPClaim.status
              │
              ▼
         Generates NADs
              │
              ▼
         ConfigSync
              │
              ▼
    ┌─────────────────────────────────────┐
    │    Workload Cluster (edge-node-1)   │
    ├─────────────────────────────────────┤
    │ NAD: n2                             │
    │ NAD: n3                             │
    │ NAD: ru                             │
    │                                      │
    │ OAI Operator ──> Creates ──> gNB Pod│
    │                              (Uses NADs)
    └─────────────────────────────────────┘
```

## Summary: Your Complete Setup

```
┌───────────────────────────────────────────────────────────────┐
│                  WHAT YOU HAVE                                 │
├───────────────────────────────────────────────────────────────┤
│                                                                │
│ Physical Infrastructure:                                       │
│ ✅ Single node cluster (edge-node-1)                          │
│ ✅ ens3 NIC (for N2, N3)                                      │
│ ✅ ens4 NIC (optional, for RU)                                │
│                                                                │
│ K8s Infrastructure (from your blueprints):                     │
│ ✅ cluster-baseline                                            │
│ ✅ addons                                                      │
│ ✅ Multus CNI                                                  │
│ ✅ Calico CNI (primary)                                        │
│                                                                │
│ Nephio Packages (I created):                                   │
│ ✅ Interface resources (N2, N3, RU)                           │
│ ✅ NetworkInstance resources                                   │
│ ✅ Kptfile with readiness gates                               │
│                                                                │
│ What You Need to Add:                                          │
│ ⚠️ IPPrefix resources (IP pools) - Simple YAML               │
│ ⚠️ WorkloadCluster resource - Simple YAML                     │
│ ⚠️ OAI RAN Operator PackageVariant                           │
│ ⚠️ OAI gNB Deployment PackageVariant                         │
│                                                                │
│ Result:                                                         │
│ ✅ 1 Pod: oai-gnb-0                                           │
│ ✅ 4 Interfaces: eth0, net1 (N2), net2 (N3), net3 (RU)       │
│ ✅ 3 NADs: n2, n3, ru                                         │
│ ✅ Full connectivity to Core (AMF, UPF)                       │
└───────────────────────────────────────────────────────────────┘
```

This topology shows your complete single-node OAI gNB deployment with all pods, interfaces, NADs, and network flows clearly visualized!
