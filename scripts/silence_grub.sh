#!/usr/bin/env bash
# ==============================================================================
# ◈ NEXUS DUAL BOOT ◈ — Silenciador de GRUB para Transição Direta
# ==============================================================================
set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "[-] Este script precisa ser executado como root: sudo bash scripts/silence_grub.sh" >&2
   exit 1
fi

GRUB_FILE="/etc/default/grub"

if [[ ! -f "$GRUB_FILE" ]]; then
    echo "[-] Arquivo $GRUB_FILE não encontrado." >&2
    exit 1
fi

# Backup original
if [[ ! -f "${GRUB_FILE}.nexus-orig" ]]; then
    cp -f "$GRUB_FILE" "${GRUB_FILE}.nexus-orig"
    echo "[+] Backup de segurança criado em ${GRUB_FILE}.nexus-orig"
fi

# Ajustar timeout e ocultar menu
sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' "$GRUB_FILE"

if grep -q "^GRUB_TIMEOUT_STYLE=" "$GRUB_FILE"; then
    sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' "$GRUB_FILE"
else
    echo 'GRUB_TIMEOUT_STYLE=hidden' >> "$GRUB_FILE"
fi

if grep -q "^GRUB_RECORDFAIL_TIMEOUT=" "$GRUB_FILE"; then
    sed -i 's/^GRUB_RECORDFAIL_TIMEOUT=.*/GRUB_RECORDFAIL_TIMEOUT=0/' "$GRUB_FILE"
else
    echo 'GRUB_RECORDFAIL_TIMEOUT=0' >> "$GRUB_FILE"
fi

if grep -q "^GRUB_DISABLE_OS_PROBER=" "$GRUB_FILE"; then
    sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' "$GRUB_FILE"
else
    echo 'GRUB_DISABLE_OS_PROBER=true' >> "$GRUB_FILE"
fi

# Configura GRUB_CMDLINE_LINUX_DEFAULT se necessário para splash limpo
echo "[+] Atualizando configurações do GRUB via update-grub..."
update-grub

echo "[+] Concluído com sucesso! O menu do GRUB foi silenciado."
