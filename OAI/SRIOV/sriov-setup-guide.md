# SR-IOV Setup Guide for N3 Interface

## Prerequisites

### Hardware Requirements

You need an SR-IOV capable NIC. Recommended models:

**Intel:**
- Intel E810 (Columbiaville) ✅ **Best choice**
- Intel XL710/X710 (Fortville)
- Intel 82599ES (older)

**Mellanox/NVIDIA:**
- ConnectX-6 Dx/Lx ✅
- ConnectX-5
- ConnectX-7

### Check if Your NIC Supports SR-IOV

```bash
# List all network devices
lspci | grep -i ethernet

# Example output:
# 01:00.0 Ethernet controller: Intel Corporation Ethernet Controller E810-C for QSFP (rev 02)
# 02:00.0 Ethernet controller: Intel Corporation I350 Gigabit Network Connection

# Check SR-IOV capability
lspci -vvv -s 01:00.0 | grep -i sr-iov

# Should show:
# Capabilities: [160] Single Root I/O Virtualization (SR-IOV)
#     SR-IOV Capabilities: ...
#     Initial VFs: 64, Total VFs: 64, ...
```

## Step-by-Step SR-IOV Setup

### Step 1: Enable SR-IOV in BIOS

```
1. Reboot and enter BIOS/UEFI
2. Navigate to: Advanced → PCI Configuration
3. Enable:
   - SR-IOV Support: Enabled
   - VT-d (Intel) / IOMMU (AMD): Enabled
   - ACS (Access Control Services): Enabled
4. Save and reboot
```

### Step 2: Enable IOMMU in Kernel

```bash
# Edit GRUB configuration
sudo vi /etc/default/grub

# Add to GRUB_CMDLINE_LINUX:
# For Intel:
GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt"

# For AMD:
GRUB_CMDLINE_LINUX="amd_iommu=on iommu=pt"

# Update GRUB
sudo update-grub  # Ubuntu/Debian
# OR
sudo grub2-mkconfig -o /boot/grub2/grub.cfg  # RHEL/CentOS

# Reboot
sudo reboot
```

### Step 3: Verify IOMMU is Enabled

```bash
# Check IOMMU status
dmesg | grep -i iommu

# Should show:
# DMAR: IOMMU enabled
# Intel-IOMMU: enabled

# Check if VT-d/IOMMU groups exist
ls /sys/kernel/iommu_groups/

# Should show numbered directories (0, 1, 2, ...)
```

### Step 4: Load Required Kernel Modules

```bash
# For Intel NICs
sudo modprobe vfio-pci
sudo modprobe ice       # E810 driver
sudo modprobe iavf      # VF driver

# For Mellanox NICs
sudo modprobe mlx5_core
sudo modprobe mlx5_ib

# Make modules load on boot
echo "vfio-pci" | sudo tee -a /etc/modules
echo "ice" | sudo tee -a /etc/modules
echo "iavf" | sudo tee -a /etc/modules
```

### Step 5: Create Virtual Functions (VFs)

```bash
# Identify your SR-IOV NIC
export PF_DEVICE=ens4

# Enable 4 VFs
echo 4 | sudo tee /sys/class/net/${PF_DEVICE}/device/sriov_numvfs

# Verify VFs created
lspci | grep "Virtual Function"

# Should show:
# 01:00.1 Ethernet controller: Intel Corporation Ethernet Virtual Function 700 Series
# 01:00.2 Ethernet controller: Intel Corporation Ethernet Virtual Function 700 Series
# 01:00.3 Ethernet controller: Intel Corporation Ethernet Virtual Function 700 Series
# 01:00.4 Ethernet controller: Intel Corporation Ethernet Virtual Function 700 Series

# Check VF interfaces
ip link show

# Should show new interfaces like:
# ens4v0, ens4v1, ens4v2, ens4v3
```

### Step 6: Make VF Creation Persistent

```bash
# Create systemd service
sudo tee /etc/systemd/system/sriov-vfs.service << EOF
[Unit]
Description=Create SR-IOV Virtual Functions
After=network.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'echo 4 > /sys/class/net/ens4/device/sriov_numvfs'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable service
sudo systemctl enable sriov-vfs.service
sudo systemctl start sriov-vfs.service
sudo systemctl status sriov-vfs.service
```

### Step 7: Install SR-IOV CNI Plugin

```bash
# Download SR-IOV CNI plugin
wget https://github.com/k8snetworkplumbingwg/sriov-cni/releases/download/v2.7.0/sriov-cni-v2.7.0.tar.gz

# Extract to CNI plugins directory
sudo tar -xzf sriov-cni-v2.7.0.tar.gz -C /opt/cni/bin/

# Verify
ls -la /opt/cni/bin/sriov

# Should show the sriov binary
```

### Step 8: Install SR-IOV Device Plugin

```bash
# Apply SR-IOV Device Plugin DaemonSet
kubectl apply -f https://raw.githubusercontent.com/k8snetworkplumbingwg/sriov-network-device-plugin/master/deployments/k8s-v1.16/sriovdp-daemonset.yaml

# Verify deployment
kubectl get pods -n kube-system | grep sriov

# Should show:
# kube-sriov-device-plugin-amd64-xxxxx   1/1     Running   0          30s
```

### Step 9: Configure SR-IOV Device Plugin

```bash
# Create ConfigMap for SR-IOV Device Plugin
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: sriovdp-config
  namespace: kube-system
data:
  config.json: |
    {
      "resourceList": [
        {
          "resourceName": "intel_sriov_n3",
          "resourcePrefix": "intel.com",
          "selectors": {
            "vendors": ["8086"],
            "devices": ["1592"],
            "drivers": ["iavf"],
            "pfNames": ["ens4"]
          }
        }
      ]
    }
EOF

# For Mellanox ConnectX-6:
# "vendors": ["15b3"]
# "devices": ["101e"]
# "drivers": ["mlx5_core"]

# Restart SR-IOV device plugin to pick up config
kubectl delete pod -n kube-system -l app=sriovdp
```

### Step 10: Verify SR-IOV Resources

```bash
# Check if SR-IOV resources are advertised
kubectl get node <node-name> -o json | jq '.status.allocatable'

# Should show:
# {
#   ...
#   "intel.com/intel_sriov_n3": "4",
#   ...
# }

# This means 4 VFs are available for allocation
```

## Testing SR-IOV

### Test 1: Create Test Pod with SR-IOV

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-sriov
  namespace: default
spec:
  containers:
  - name: test
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
    resources:
      requests:
        intel.com/intel_sriov_n3: '1'
      limits:
        intel.com/intel_sriov_n3: '1'
EOF

# Wait for pod to be running
kubectl wait --for=condition=Ready pod/test-sriov --timeout=60s

# Check pod interfaces
kubectl exec test-sriov -- ip addr

# Should show a VF interface (net1) with a specific PCI address
```

### Test 2: Verify VF Assignment

```bash
# Check which VF is assigned to the pod
kubectl exec test-sriov -- cat /sys/class/net/net1/device/uevent

# Should show something like:
# PCI_SLOT_NAME=0000:01:00.1
# PCI_ID=8086:154C

# On the host, verify VF is assigned
ip link show ens4

# The VF should show as "vf 0" or similar with the pod's namespace
```

### Test 3: VF-to-VF Communication Test

```bash
# Create two test pods
kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: test-sriov-1
spec:
  containers:
  - name: test
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
    resources:
      limits:
        intel.com/intel_sriov_n3: '1'
---
apiVersion: v1
kind: Pod
metadata:
  name: test-sriov-2
spec:
  containers:
  - name: test
    image: nicolaka/netshoot
    command: ["sleep", "infinity"]
    resources:
      limits:
        intel.com/intel_sriov_n3: '1'
EOF

# Wait for pods
kubectl wait --for=condition=Ready pod/test-sriov-1 pod/test-sriov-2 --timeout=60s

# Get IP of pod 2
POD2_IP=$(kubectl exec test-sriov-2 -- ip -4 addr show net1 | grep inet | awk '{print $2}' | cut -d/ -f1)

# Ping from pod 1 to pod 2
kubectl exec test-sriov-1 -- ping -c 4 $POD2_IP

# Should show successful pings with low latency (<1ms)
```

## Expected NAD Generated by Nephio

With SR-IOV configuration, Nephio will generate a NAD like this:

```yaml
apiVersion: k8s.cni.cncf.io/v1
kind: NetworkAttachmentDefinition
metadata:
  name: n3
  namespace: oai-ran
spec:
  config: |
    {
      "cniVersion": "0.3.1",
      "type": "sriov",
      "ipam": {
        "type": "static",
        "addresses": [
          {
            "address": "10.1.3.20/24",
            "gateway": "10.1.3.1"
          }
        ]
      }
    }
```

## Troubleshooting SR-IOV

### Issue: No VFs Created

```bash
# Check if SR-IOV is supported
lspci -vvv -s <device-id> | grep SR-IOV

# Check kernel logs
dmesg | grep -i sriov

# Check if IOMMU is enabled
cat /proc/cmdline | grep iommu

# Try different number of VFs
echo 0 | sudo tee /sys/class/net/ens4/device/sriov_numvfs
echo 2 | sudo tee /sys/class/net/ens4/device/sriov_numvfs
```

### Issue: SR-IOV Device Plugin Not Discovering VFs

```bash
# Check device plugin logs
kubectl logs -n kube-system -l app=sriovdp

# Verify config
kubectl get configmap sriovdp-config -n kube-system -o yaml

# Check device IDs match
lspci -nn | grep -i ethernet

# Update ConfigMap with correct IDs
```

### Issue: VF-to-VF Communication Not Working

```bash
# Check NIC firmware supports VF-to-VF
# Intel E810: Update to latest firmware
ethtool -i ens4

# Mellanox: Enable eswitch mode
sudo mlxconfig -d /dev/mst/mt4121_pciconf0 set SRIOV_EN=1 NUM_OF_VFS=4

# Check if VFs are in same bridge
bridge fdb show
```

### Issue: Performance Not as Expected

```bash
# Check MTU
ip link show ens4

# Enable jumbo frames
sudo ip link set ens4 mtu 9000
sudo ip link set ens4v0 mtu 9000

# Check if RSS (Receive Side Scaling) is enabled
ethtool -l ens4

# Increase queues if needed
sudo ethtool -L ens4 combined 4
```

## Performance Verification

```bash
# Install iperf3 in test pods
kubectl exec test-sriov-1 -- apt update && apt install -y iperf3
kubectl exec test-sriov-2 -- apt update && apt install -y iperf3

# Run iperf server on pod 2
kubectl exec test-sriov-2 -- iperf3 -s &

# Run iperf client on pod 1
kubectl exec test-sriov-1 -- iperf3 -c $POD2_IP -t 10

# Expected results with SR-IOV VF-to-VF:
# - Bandwidth: 5-10 Gbps (or higher depending on NIC)
# - Latency: <100 microseconds
# - CPU usage: Near zero (hardware forwarding)
```

## Summary

```
┌─────────────────────────────────────────────────────────────┐
│              SR-IOV Setup Checklist                          │
├─────────────────────────────────────────────────────────────┤
│ ✅ BIOS: SR-IOV enabled, VT-d/IOMMU enabled               │
│ ✅ Kernel: IOMMU enabled in boot parameters                │
│ ✅ Modules: vfio-pci, ice/iavf loaded                      │
│ ✅ VFs: Created (4 VFs on ens4)                            │
│ ✅ Persistent: Systemd service for VF creation             │
│ ✅ CNI: SR-IOV CNI plugin installed                        │
│ ✅ Device Plugin: SR-IOV device plugin running             │
│ ✅ ConfigMap: SR-IOV resources configured                  │
│ ✅ Verification: SR-IOV resources visible on node          │
│ ✅ Testing: VF-to-VF communication working                 │
└─────────────────────────────────────────────────────────────┘
```

Once SR-IOV is set up, Nephio will automatically use it for N3 interfaces when you specify `cniType: sriov` in the Interface resource!
