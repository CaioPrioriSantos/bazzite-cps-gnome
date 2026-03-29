#!/bin/bash
# ==============================================================================
# bazzite-cps-gnome — build.sh
# KERNEL_FLAVOR: "bazzite" (default) | "cachyos"
#
# Variante bazzite : kernel Bazzite + melhorias CachyOS runtime
# Variante cachyos : kernel CachyOS LTO (Clang + ThinLTO + AutoFDO + Propeller) + melhorias runtime
# ==============================================================================
set -ouex pipefail

KERNEL_FLAVOR="${KERNEL_FLAVOR:-bazzite}"

rm -f /etc/yum.repos.d/*terra*.repo || true
dnf5 config-manager setopt terra.enabled=0 terra-extras.enabled=0 terra-mesa.enabled=0 2>/dev/null || true

dnf5 install -y \
    tmux \
    asusctl \
    supergfxctl \
    rog-control-center

systemctl enable podman.socket
systemctl enable asusd.service
systemctl enable supergfxd.service

dnf5 copr enable -y bieszczaders/kernel-cachyos-addons

dnf5 install -y \
    cachyos-settings \
    scx-scheds

systemctl enable scx.service
echo 'SCX_SCHEDULER=scx_lavd' > /etc/default/scx

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
