#!/bin/bash
# ==============================================================================
# bazzite-cps-gnome — build.sh
# KERNEL_FLAVOR: "bazzite" (default) | "cachyos"
# ==============================================================================
set -ouex pipefail

KERNEL_FLAVOR="${KERNEL_FLAVOR:-bazzite}"

rm -f /etc/yum.repos.d/*terra*.repo || true
dnf5 config-manager setopt terra.enabled=0 terra-extras.enabled=0 terra-mesa.enabled=0 2>/dev/null || true

dnf5 copr enable -y lukenukem/asus-linux

dnf5 install -y \
    asusctl \
    supergfxctl \
    rog-control-center

systemctl enable podman.socket
systemctl enable asusd.service
systemctl enable supergfxd.service

dnf5 copr enable -y bieszczaders/kernel-cachyos-addons
# scx-scheds já vem no Bazzite; cachyos-settings conflitua com zram-generator-defaults

systemctl enable scx.service 2>/dev/null || true
echo 'SCX_SCHEDULER=scx_lavd' > /etc/default/scx

cat > /usr/lib/sysctl.d/99-bazzite-cps-perf.conf << 'SYSCTL'
vm.vfs_cache_pressure = 50
vm.dirty_bytes = 268435456
vm.dirty_background_bytes = 67108864
vm.dirty_writeback_centisecs = 1500
vm.page-cluster = 0
kernel.nmi_watchdog = 0
net.core.netdev_max_backlog = 16384
fs.file-max = 2097152
SYSCTL

cat > /usr/lib/modprobe.d/99-bazzite-cps-audio.conf << 'MODPROBE'
options snd_hda_intel power_save=0
MODPROBE

cat > /usr/lib/modprobe.d/99-bazzite-cps-watchdog.conf << 'MODPROBE'
blacklist iTCO_wdt
blacklist sp5100_tco
MODPROBE

cat > /usr/lib/udev/rules.d/99-bazzite-cps-audio-timers.rules << 'UDEV'
KERNEL=="rtc0", GROUP="audio"
KERNEL=="hpet", GROUP="audio"
UDEV

cat > /usr/lib/udev/rules.d/99-bazzite-cps-audio-pm.rules << 'UDEV'
ACTION=="add", SUBSYSTEM=="sound", KERNEL=="card*", DRIVERS=="snd_hda_intel", \
  TEST!="/run/udev/snd-hda-intel-powersave", \
  RUN+="/usr/bin/bash -c 'touch /run/udev/snd-hda-intel-powersave; \
    [[ $$(cat /sys/class/power_supply/BAT0/status 2>/dev/null) != \"Discharging\" ]] && \
    echo 0 > /sys/module/snd_hda_intel/parameters/power_save'"
UDEV

if [[ "${KERNEL_FLAVOR}" == "cachyos" ]]; then

    dnf5 copr enable -y bieszczaders/kernel-cachyos-lto

    BAZZITE_KERNEL_PKGS=$(rpm -qa --queryformat '%{NAME}\n' \
        | grep -E '^kernel(-core|-modules|-modules-core|-modules-extra|-modules-internal|-uki-virt)?$' \
        | sort -u)

    dnf5 install -y \
        kernel-cachyos-lto \
        kernel-cachyos-lto-devel-matched

    if [[ -n "${BAZZITE_KERNEL_PKGS}" ]]; then
        echo "${BAZZITE_KERNEL_PKGS}" | xargs dnf5 remove -y
    fi

    echo "kernel-cachyos-lto instalado com sucesso"

else
    echo "kernel Bazzite mantido — melhorias CachyOS runtime aplicadas"
fi

# CPU DMA latency — acesso sem root para PipeWire/JACK
cat > /usr/lib/udev/rules.d/99-bazzite-cps-dma-latency.rules << 'UDEV'
KERNEL=="cpu_dma_latency", GROUP="audio", MODE="0660"
UDEV

# journald — limita logs a 50MB
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/99-bazzite-cps.conf << 'JOURNALD'
[Journal]
SystemMaxUse=50M
JOURNALD

# Service timeouts — boot/shutdown mais rápido
mkdir -p /etc/systemd/system.conf.d
cat > /etc/systemd/system.conf.d/99-bazzite-cps-timeouts.conf << 'SYSTEMD'
[Manager]
DefaultTimeoutStartSec=15s
DefaultTimeoutStopSec=10s
SYSTEMD
