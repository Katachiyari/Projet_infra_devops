#!/usr/bin/env bash
set -euo pipefail
 
# ==============================
# Proxmox Cloud-Init Template
# Debian 13 (trixie) - Idempotent
# ==============================
 
VMID="${VMID:-9000}"
NAME="${NAME:-debian13-cloudinit}"
STORAGE="${STORAGE:-local-lvm}"
BRIDGE="${BRIDGE:-vmbr0}"
MEMORY="${MEMORY:-2048}"
CORES="${CORES:-2}"
 
IMAGE_URL="${IMAGE_URL:-https://cloud.debian.org/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2}"
IMAGE_DIR="${IMAGE_DIR:-/var/lib/vz/template/cache}"
IMAGE_FILE="${IMAGE_FILE:-${IMAGE_DIR}/debian-13-genericcloud-amd64.qcow2}"
 
need_root() { [[ "${EUID}" -eq 0 ]] || { echo "ERROR: run as root (sudo)." >&2; exit 1; }; }
require_cmd() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: missing command: $1" >&2; exit 1; }; }
vm_exists() { qm status "$VMID" >/dev/null 2>&1; }
is_template() { qm config "$VMID" 2>/dev/null | grep -qE '^\s*template:\s*1\s*$'; }
has_config_line() { qm config "$VMID" | grep -qE "^\s*$1:"; }
 
download_image_if_needed() {
  mkdir -p "$IMAGE_DIR"
  [[ -f "$IMAGE_FILE" ]] && { echo "OK: image present: $IMAGE_FILE"; return 0; }
  echo "Downloading Debian cloud image..."
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 --output "$IMAGE_FILE" "$IMAGE_URL"
  else
    require_cmd wget
    wget -O "$IMAGE_FILE" "$IMAGE_URL"
  fi
}
 
create_vm_if_needed() {
  vm_exists && { echo "OK: VMID $VMID exists"; return 0; }
  echo "Creating VM $VMID ($NAME)..."
  qm create "$VMID" \
    --name "$NAME" \
    --memory "$MEMORY" \
    --cores "$CORES" \
    --net0 "virtio,bridge=${BRIDGE}" >/dev/null
}
 
import_and_attach_disk_if_needed() {
  # If scsi0 already set, assume disk is attached
  if has_config_line "scsi0"; then
    echo "OK: scsi0 already configured"
    return 0
  fi
 
  echo "Importing qcow2 into ${STORAGE}..."
  # Capture output to extract the created volume id
  # Typical output includes something like: "successfully imported disk as 'local-lvm:vm-9000-disk-0'"
  local out vol
  out="$(qm importdisk "$VMID" "$IMAGE_FILE" "$STORAGE" 2>&1 | tee /dev/stderr)"
 
  vol="$(echo "$out" | grep -oE "${STORAGE}:vm-${VMID}-disk-[0-9]+" | tail -n1 || true)"
  if [[ -z "$vol" ]]; then
    echo "ERROR: cannot detect imported volume id from qm importdisk output." >&2
    echo "Hint: run: pvesm list ${STORAGE} | grep vm-${VMID}-disk" >&2
    exit 1
  fi
 
  echo "Attaching imported disk as scsi0: ${vol}"
  qm set "$VMID" --scsihw virtio-scsi-pci --scsi0 "$vol" >/dev/null
}
 
configure_cloudinit() {
  # Cloud-init drive (ide2)
  if ! has_config_line "ide2"; then
    qm set "$VMID" --ide2 "${STORAGE}:cloudinit" >/dev/null
  fi
 
  # Boot from scsi0 explicitly
  qm set "$VMID" --boot "order=scsi0" >/dev/null
 
  # Recommended machine defaults
  if ! has_config_line "agent"; then
    qm set "$VMID" --agent enabled=1 >/dev/null
  fi
 
  # SPICE/QXL (do this before template)
  qm set "$VMID" --vga qxl >/dev/null
 
  # Optional: if you previously set serial0/vga serial0, remove serial0 to avoid confusion
  if has_config_line "serial0"; then
    qm set "$VMID" --delete serial0 >/dev/null || true
  fi
}
 
convert_to_template_if_needed() {
  is_template && { echo "OK: already a template"; return 0; }
  qm stop "$VMID" --skiplock 1 >/dev/null 2>&1 || true
  qm template "$VMID" >/dev/null
}
 
main() {
  need_root
  require_cmd qm
 
  echo "=== Proxmox Debian 13 cloud-init template itlab==="
  echo "VMID=$VMID NAME=$NAME STORAGE=$STORAGE BRIDGE=$BRIDGE"
 
  download_image_if_needed
  create_vm_if_needed
  import_and_attach_disk_if_needed
  configure_cloudinit
  convert_to_template_if_needed
 
  echo "DONE: Template $VMID ($NAME) ready."
  echo "Check: qm config $VMID | egrep 'scsi0|ide2|boot|vga|agent|template'"
}
 
main "$@"