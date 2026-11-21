#!/usr/bin/env bash
# ==============================================================================
# ◈ NEXUS DUAL BOOT ◈ — Script de Desinstalação e Limpeza Segura
# Restaura o estado original do sistema operacional e da partição EFI
# ==============================================================================
set -euo pipefail

ESP_MOUNT="/boot/efi"
for candidate in "/boot/efi" "/efi" "/boot/EFI" "/boot"; do
    if findmnt -M "${candidate}" >/dev/null 2>&1 && [[ -d "${candidate}/EFI" ]]; then
        ESP_MOUNT="${candidate}"
        break
    fi
done

TARGET_DIR="${ESP_MOUNT}/EFI/nexus-duall-boot"

# Cores
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[-] Este script precisa ser executado como root.${NC}" >&2
   echo -e "    Por favor, execute: ${YELLOW}sudo bash uninstall.sh${NC}" >&2
   exit 1
fi

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}  ◈ NEXUS DUAL BOOT ◈ — Desinstalador e Restauração${NC}"
echo -e "${BLUE}==========================================================${NC}"

# 1. Desativar e remover o serviço de proteção (Nexus Boot Guard)
if command -v systemctl >/dev/null 2>&1; then
    if systemctl is-enabled nexus-boot-guard.service >/dev/null 2>&1 || [[ -f /etc/systemd/system/nexus-boot-guard.service ]]; then
        echo -e "[*] Desativando e removendo nexus-boot-guard.service..."
        systemctl disable nexus-boot-guard.service >/dev/null 2>&1 || true
        rm -f /etc/systemd/system/nexus-boot-guard.service
        systemctl daemon-reload
        echo -e "  [+] Serviço de persistência removido."
    fi
fi

# 2. Remover entradas UEFI da placa-mãe via efibootmgr
if command -v efibootmgr >/dev/null 2>&1; then
    EXISTING_BOOT_ENTRIES=$(efibootmgr | grep -iE "Nexus Dual Boot|rEFInd Boot Manager" | sed -E 's/Boot([0-9A-Fa-f]+).*/\1/' || true)
    for bnum in ${EXISTING_BOOT_ENTRIES}; do
        echo -e "[*] Removendo entrada Boot${bnum} da NVRAM..."
        efibootmgr -b "${bnum}" -B >/dev/null 2>&1 || true
        echo -e "  [+] Entrada Boot${bnum} removida."
    done

    # Restaura ordem de boot original com Ubuntu em primeiro
    UBUNTU_NUM=$(efibootmgr | grep -i "Ubuntu" | head -n1 | sed -E 's/Boot([0-9A-Fa-f]+).*/\1/' || true)
    WIN_NUM=$(efibootmgr | grep -i "Windows Boot Manager" | head -n1 | sed -E 's/Boot([0-9A-Fa-f]+).*/\1/' || true)
    if [[ -n "${UBUNTU_NUM}" && -n "${WIN_NUM}" ]]; then
        echo -e "[*] Restaurando prioridade oficial: Ubuntu (${UBUNTU_NUM}) -> Windows (${WIN_NUM})..."
        efibootmgr -o "${UBUNTU_NUM},${WIN_NUM}" >/dev/null 2>&1 || true
        echo -e "  [+] Ordem de boot padrão restaurada."
    fi
fi

# 3. Restaurar fallback original BOOTX64.EFI se existir backup
if [[ -f "${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI.orig" ]]; then
    echo -e "[*] Restaurando BOOTX64.EFI original..."
    mv -f "${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI.orig" "${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI"
    echo -e "  [+] Fallback original restaurado."
fi

# 4. Remover arquivos do diretório isolado e resíduos de refind padrão
for d in "${TARGET_DIR}" "${ESP_MOUNT}/EFI/refind"; do
    if [[ -d "${d}" ]]; then
        echo -e "[*] Removendo diretório ${d}..."
        rm -rf "${d}"
        echo -e "  [+] Removido da partição EFI: ${d}"
    fi
done

# 5. Restaurar configuração original do GRUB se foi silenciado pelo instalador
if [[ -f "/etc/default/grub.nexus-orig" ]] && command -v update-grub >/dev/null 2>&1; then
    echo -e "[*] Restaurando /etc/default/grub original..."
    mv -f "/etc/default/grub.nexus-orig" "/etc/default/grub"
    update-grub >/dev/null 2>&1 || true
    echo -e "  [+] Configuração original do GRUB restaurada."
fi

echo -e "\n${BLUE}==========================================================${NC}"
echo -e "  ${GREEN}✅ DESINSTALAÇÃO CONCLUÍDA!${NC}"
echo -e "  Seu sistema retornou ao estado original sem nenhuma pendência."
echo -e "${BLUE}==========================================================${NC}"
