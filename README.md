# README — Accessing a USB Drive from a Kubernetes Pod using Akri (udev)

This document records the steps taken to discover a **USB flash drive** on a Kubernetes node and access its data **from inside a Pod** using **Akri**’s `udev` discovery handler.

---

## Overview

- **Goal:** Read files from a USB drive plugged into a Kubernetes node.
- **Approach:** Use **Akri** to discover the USB block device and advertise it as a schedulable **extended resource**; schedule a **privileged Pod** that requests that resource; **mount** the block device read-only inside the Pod.

---

## 1) Identify the USB device (VID/PID)

On the node (or any host that sees the USB device):

```bash
lsusb
```

Result contained a SanDisk drive:

```
ID 0781:5567 SanDisk Corp.
```

These are the **Vendor ID** (`0781`) and **Product ID** (`5567`).

---

## 2) Install Akri with `udev` discovery enabled

Install Akri via Helm and provide a `udev` rule so the agent knows what to discover.

> Command used originally:

```bash
helm install akri akri-helm-charts/akri   --set udev.discovery.enabled=true   --set udev.configuration.enabled=true   --set udev.configuration.discoveryDetails.udevRules[0]='ATTRS{idVendor}=="0781", ATTRS{idProduct}=="5567"'
```

> **Note:** Some Akri versions prefer rules using `ENV{...}` / `SUBSYSTEMS=="usb"` rather than `ATTRS{...}`. If discovery does not produce an `AkriInstance`, use a rule like:
>
> ```bash
> --set udev.configuration.discoveryDetails.udevRules[0]='SUBSYSTEM=="block", SUBSYSTEMS=="usb", ENV{DEVTYPE}=="disk", KERNEL=="sd?"'
> ```
>
> You can then further narrow by VID/PID with:
> `ENV{ID_VENDOR_ID}=="0781", ENV{ID_MODEL_ID}=="5567"`.

---

## 3) Create an Akri `Configuration`

Create a `Configuration` named **`akri-sandisk-conf`** to define how Akri should discover the device.

```yaml
apiVersion: akri.sh/v0
kind: Configuration
metadata:
  name: akri-sandisk-conf
spec:
  capacity: 1
  discoveryHandler:
    discoveryDetails: |
      groupRecursive: true
      udevRules:
      - ATTRS{idVendor}=="0781", ATTRS{idProduct}=="5567"
    name: udev
```

- `capacity: 1` → by default, only one Pod can consume this device at a time.
- Resource name exposed to Kubernetes becomes: **`akri.sh/akri-sandisk-conf`** (i.e., `akri.sh/<configuration-name>`).

**Verify discovery:**

```bash
kubectl get akrii -o wide
kubectl get nodes -o custom-columns=NAME:.metadata.name,ALLOC:'.status.allocatable.akri\.sh/akri-sandisk-conf'
```

You should see an `AkriInstance` on the node that has the USB drive and the node advertising capacity/allocatable for `akri.sh/akri-sandisk-conf`.

---

## 4) Run a Pod that requests the device

Create a **privileged** BusyBox Pod that **requests** the Akri resource and stays alive:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
spec:
  containers:
  - name: busybox
    image: busybox:1.36
    securityContext:
      privileged: true
    command: ["sh","-c","sleep 3600000"]
    resources:
      requests:
        cpu: "100m"
        memory: "64Mi"
        akri.sh/akri-sandisk-conf: "1"
      limits:
        cpu: "200m"
        memory: "128Mi"
        akri.sh/akri-sandisk-conf: "1"
  restartPolicy: Never
```

> For extended resources like Akri’s, **requests and limits must both be set and equal**.  
> If the device exists only on a control-plane node, add a toleration and/or `nodeSelector` to schedule there.

**Confirm scheduling & start:**

```bash
kubectl describe pod busybox
kubectl get pod busybox -o wide
```

---

## 5) Access the USB **inside** the Pod

Enter the pod and identify the injected device nodes:

```bash
kubectl exec -it busybox -- sh
env | grep UDEV_DEVNODE_
# Example:
# UDEV_DEVNODE_3=/dev/sdb
# UDEV_DEVNODE_4=/dev/sdb1
# UDEV_DEVNODE_5=/dev/sdb2
```

Identify filesystem types (examples from the session):

```bash
blkid /dev/sdb1
# /dev/sdb1: LABEL="EFI" UUID="67E3-17ED" TYPE="vfat"

blkid /dev/sdb2
# /dev/sdb2: LABEL="FAPS" UUID="2964-1824" TYPE="vfat"
```

Mount a partition **read-only** and list files:

```bash
mkdir -p /mnt/usb
mount -o ro /dev/sdb2 /mnt/usb
ls -la /mnt/usb
```

When finished:

```bash
umount /mnt/usb
exit
```

---

## Troubleshooting

- **No AkriInstances found:** use an Akri-supported udev rule (avoid `ATTRS{}`); start with  
  `SUBSYSTEM=="block", SUBSYSTEMS=="usb", ENV{DEVTYPE}=="disk", KERNEL=="sd?"`.
- **Pod won’t schedule:** ensure the node with the USB advertises `akri.sh/akri-sandisk-conf` and that no other Pod uses the single slot; increase `spec.capacity` if needed.
- **Mount errors:** ensure the container is privileged; specify filesystem type (`-t vfat`, `-t ext4`, etc.).

---

## Commands used (reference)

```bash
# Identify USB device
lsusb

# Install Akri with udev discovery enabled (initial rule)
helm install akri akri-helm-charts/akri   --set udev.discovery.enabled=true   --set udev.configuration.enabled=true   --set udev.configuration.discoveryDetails.udevRules[0]='ATTRS{idVendor}=="0781", ATTRS{idProduct}=="5567"'

# Create Akri Configuration (akri-sandisk-conf) — see YAML above

# Create privileged BusyBox Pod requesting the Akri resource — see YAML above

# Inside the Pod:
blkid /dev/sdb1
blkid /dev/sdb2
mkdir -p /mnt/usb
mount -o ro /dev/sdb2 /mnt/usb
ls -la /mnt/usb
```
Minor tweak (14)
