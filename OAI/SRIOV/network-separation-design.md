# Updated Network Configuration: Separate N2 and N3 Interfaces
# N2 on ens3 (MacVLAN) + N3 on ens4 (SR-IOV)

## Physical NIC Assignment

```
┌──────────────────────────────────────────────────────────────┐
│              Single Node: edge-node-1                         │
│                                                               │
│  Physical NICs:                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ens3 (1G/10G Standard NIC)                         │    │
│  │  ├─ Purpose: N2 Control Plane                       │    │
│  │  ├─ Technology: MacVLAN                              │    │
│  │  ├─ Workloads: gNB N2 → AMF                         │    │
│  │  └─ Bandwidth: ~100 Mbps (control plane)            │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ens4 (SR-IOV Capable NIC)                          │    │
│  │  ├─ Purpose: N3 User Plane (High Performance)       │    │
│  │  ├─ Technology: SR-IOV with VF-to-VF                │    │
│  │  ├─ Workloads:                                       │    │
│  │  │  ├─ gNB N3 (VF 0)                                │    │
│  │  │  └─ UPF N3 (VF 1)                                │    │
│  │  ├─ VF-to-VF: Hardware forwarding (zero CPU)        │    │
│  │  └─ Bandwidth: 1-10 Gbps (user plane data)          │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  ens5 (Optional - for RU/USRP if available)         │    │
│  │  ├─ Purpose: Fronthaul to Radio Unit                │    │
│  │  ├─ Technology: MacVLAN                              │    │
│  │  ├─ MTU: 9000                                        │    │
│  │  └─ Workloads: gNB RU → USRP                        │    │
│  └─────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────┘
```

## Detailed Topology with Separate Interfaces

```
┌────────────────────────────────────────────────────────────────────────────┐
│                          Single Node Cluster                                │
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────┐     │
│  │                    Namespace: oai-ran                             │     │
│  │  ┌────────────────────────────────────────────────────────────┐  │     │
│  │  │  OAI gNB Pod                                                │  │     │
│  │  │                                                             │  │     │
│  │  │  eth0 (PRIMARY - Calico)                                   │  │     │
│  │  │  └─ 10.244.0.20/24  → K8s internal                        │  │     │
│  │  │                                                             │  │     │
│  │  │  net1 (SECONDARY - N2) ────────────────┐                  │  │     │
│  │  │  ├─ NAD: n2-gnb                         │                  │  │     │
│  │  │  ├─ Type: MacVLAN (ens3)                │                  │  │     │
│  │  │  ├─ IP: 10.1.2.20/24                    │                  │  │     │
│  │  │  └─ To: AMF (Control Plane)             │                  │  │     │
│  │  │                                          │                  │  │     │
│  │  │  net2 (SECONDARY - N3) ────────────────────────────┐       │  │     │
│  │  │  ├─ NAD: n3-gnb                         │           │       │  │     │
│  │  │  ├─ Type: SR-IOV VF (ens4)              │           │       │  │     │
│  │  │  ├─ IP: 10.1.3.20/24                    │           │       │  │     │
│  │  │  └─ To: UPF (User Plane) same node      │           │       │  │     │
│  │  │                                          │           │       │  │     │
│  │  │  net3 (SECONDARY - RU) ───────────────────────┐     │       │  │     │
│  │  │  ├─ NAD: ru-gnb                         │     │     │       │  │     │
│  │  │  ├─ Type: MacVLAN (ens5)                │     │     │       │  │     │
│  │  │  ├─ IP: 10.2.6.20/24                    │     │     │       │  │     │
│  │  │  ├─ MTU: 9000                            │     │     │       │  │     │
│  │  │  └─ To: USRP/RU                          │     │     │       │  │     │
│  │  └────────────────────────────────────────────────┼─────┼───────┼──┘     │
│  └────────────────────────────────────────────────────┼─────┼───────┼────────┤
│                                                       │     │       │        │
│  ┌────────────────────────────────────────────────────┼─────┼───────┼────┐  │
│  │                    Namespace: upf                  │     │       │    │  │
│  │  ┌──────────────────────────────────────────────────┼─────┼───────┼──┐│  │
│  │  │  UPF Pod                                        │     │       │  ││  │
│  │  │                                                 │     │       │  ││  │
│  │  │  eth0 (PRIMARY - Calico)                        │     │       │  ││  │
│  │  │  └─ 10.244.0.25/24  → K8s internal             │     │       │  ││  │
│  │  │                                                 │     │       │  ││  │
│  │  │  net1 (SECONDARY - N3) ◄─────────────────────────────┘       │  ││  │
│  │  │  ├─ NAD: n3-upf                                             │  ││  │
│  │  │  ├─ Type: SR-IOV VF (ens4)                                  │  ││  │
│  │  │  ├─ IP: 10.1.3.3/24                                         │  ││  │
│  │  │  └─ From: gNB (User Plane) same node                        │  ││  │
│  │  │                                                              │  ││  │
│  │  │  net2 (SECONDARY - N6) ──────────────────────────────────────────┼──┤
│  │  │  ├─ NAD: n6-upf                                             │  ││  │
│  │  │  ├─ Type: MacVLAN (ens3)                                    │  ││  │
│  │  │  ├─ IP: 192.168.250.3/24                                    │  ││  │
│  │  │  └─ To: Data Network/Internet                               │  ││  │
│  │  │                                                              │  ││  │
│  │  │  net3 (SECONDARY - N4) ◄──────────────────────────────────────┘│  │
│  │  │  ├─ NAD: n4-upf                                                │  │
│  │  │  ├─ Type: MacVLAN (ens3)                                       │  │
│  │  │  ├─ IP: 10.0.0.3/24                                            │  │
│  │  │  └─ To: SMF (Core DC)                                          │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │
│  └───────────────────────────────────────────────────────────────────────┘
│                                                                             │
│  ┌──────────────────────────────────────────────────────────────────┐     │
│  │                Physical Network Interfaces                        │     │
│  │                                                                   │     │
│  │  ens3 (Standard NIC)                                              │     │
│  │  ├─ MacVLAN Master for:                                           │     │
│  │  │  ├─ gNB net1 (N2) → 10.1.2.20                                │     │
│  │  │  ├─ UPF net2 (N6) → 192.168.250.3                            │     │
│  │  │  └─ UPF net3 (N4) → 10.0.0.3                                 │     │
│  │  └─ Speed: 1G/10G                                                │     │
│  │                                                                   │     │
│  │  ens4 (SR-IOV NIC - Intel E810 or Mellanox ConnectX)            │     │
│  │  ├─ Physical Function (PF)                                       │     │
│  │  ├─ Virtual Functions (VFs): 4 created                          │     │
│  │  │  ├─ VF 0 → gNB net2 (N3) → 10.1.3.20                        │     │
│  │  │  ├─ VF 1 → UPF net1 (N3) → 10.1.3.3                         │     │
│  │  │  ├─ VF 2 → Available                                         │     │
│  │  │  └─ VF 3 → Available                                         │     │
│  │  ├─ VF-to-VF forwarding: Hardware (zero CPU)                   │     │
│  │  └─ Speed: 10G/25G                                              │     │
│  │                                                                   │     │
│  │  ens5 (Optional - for RU)                                        │     │
│  │  ├─ MacVLAN Master for:                                          │     │
│  │  │  └─ gNB net3 (RU) → 10.2.6.20                               │     │
│  │  ├─ MTU: 9000                                                    │     │
│  │  └─ To: USRP B210                                                │     │
│  └──────────────────────────────────────────────────────────────────┘     │
└────────────────────────────────────────────────────────────────────────────┘

External Connections:
  N2 (via ens3) ─────────► AMF (Core DC)
  N3 (via ens4) ─────────► Internal VF-to-VF (gNB ↔ UPF)
  N6 (via ens3) ─────────► Internet/Data Network
  N4 (via ens3) ─────────► SMF (Core DC)
  RU (via ens5) ─────────► USRP B210
```

## Network Interface Summary

```
┌────────────────────────────────────────────────────────────────────────┐
│                    Network Interface Mapping                            │
├──────────────┬─────────────┬──────────────┬────────────┬──────────────┤
│ Workload     │ Interface   │ Physical NIC │ Technology │ Purpose      │
├──────────────┼─────────────┼──────────────┼────────────┼──────────────┤
│ gNB          │ net1 (N2)   │ ens3         │ MacVLAN    │ To AMF       │
│              │ net2 (N3)   │ ens4 (VF 0)  │ SR-IOV     │ To UPF       │
│              │ net3 (RU)   │ ens5         │ MacVLAN    │ To USRP      │
├──────────────┼─────────────┼──────────────┼────────────┼──────────────┤
│ UPF          │ net1 (N3)   │ ens4 (VF 1)  │ SR-IOV     │ From gNB     │
│              │ net2 (N6)   │ ens3         │ MacVLAN    │ To Internet  │
│              │ net3 (N4)   │ ens3         │ MacVLAN    │ To SMF       │
└──────────────┴─────────────┴──────────────┴────────────┴──────────────┘
```

## SR-IOV N3 Traffic Flow

```
┌──────────────────────────────────────────────────────────────────────┐
│                N3 User Plane Traffic (SR-IOV)                         │
│                                                                       │
│  gNB Pod                                                              │
│  └─ net2 (10.1.3.20) ──┐                                            │
│                        │                                             │
│                        ▼                                             │
│                   SR-IOV VF 0                                        │
│                        │                                             │
│                        ▼                                             │
│              ┌─────────────────────────┐                            │
│              │   Intel E810 NIC        │                            │
│              │   Hardware Switch       │                            │
│              │   (Embedded)            │                            │
│              │                         │                            │
│              │   VF 0 ◄──────► VF 1   │  ← Zero CPU forwarding!   │
│              │   (gNB)         (UPF)   │                            │
│              └─────────────────────────┘                            │
│                        │                                             │
│                        ▼                                             │
│                   SR-IOV VF 1                                        │
│                        │                                             │
│                        ▼                                             │
│  UPF Pod                                                              │
│  └─ net1 (10.1.3.3) ◄──┘                                            │
│                                                                       │
│  Benefits:                                                            │
│  ✅ Hardware packet forwarding (no kernel)                          │
│  ✅ Near line-rate performance (10-100 Gbps)                        │
│  ✅ Zero CPU overhead for N3 traffic                                │
│  ✅ Lowest latency (<10 microseconds)                               │
│  ✅ Same config works when pods on different nodes                  │
└──────────────────────────────────────────────────────────────────────┘
```

## Why This Design?

```
┌────────────────────────────────────────────────────────────────────┐
│                    Rationale for Separation                         │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  N2 (Control Plane) on ens3 with MacVLAN:                         │
│  ✅ Low bandwidth requirements (~100 Mbps)                         │
│  ✅ Latency tolerant (100ms acceptable)                            │
│  ✅ MacVLAN sufficient, SR-IOV overkill                            │
│  ✅ Shares ens3 with N6, N4 (all low bandwidth)                    │
│                                                                     │
│  N3 (User Plane) on ens4 with SR-IOV:                             │
│  ✅ High bandwidth requirements (1-10 Gbps)                        │
│  ✅ Latency critical (<1ms)                                        │
│  ✅ SR-IOV hardware acceleration essential                         │
│  ✅ VF-to-VF for same-node gNB↔UPF (zero CPU)                    │
│  ✅ Dedicated NIC avoids contention                                │
│  ✅ Future-proof: works when UPF moves to different node           │
│                                                                     │
│  Bandwidth Distribution:                                            │
│  ens3: N2 (100 Mbps) + N6 (500 Mbps) + N4 (50 Mbps) = ~650 Mbps  │
│  ens4: N3 (5-10 Gbps) = Dedicated for user plane                  │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```
