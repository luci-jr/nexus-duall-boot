#!/usr/bin/env bash
# ==============================================================================
# ◈ NEXUS DUAL BOOT ◈ — Criador de Pendrive de Teste UEFI (Live USB)
# Permite testar o seletor visual no seu PC real antes de instalar no disco.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}  ◈ NEXUS DUAL BOOT ◈ — Criador de Pendrive de Teste${NC}"
echo -e "${BLUE}==========================================================${NC}"
echo -e "\n${CYAN}Este script copia o Nexus Dual Boot para um pendrive FAT32.${NC}"
echo -e "Você poderá reiniciar o PC, apertar F12 (Boot Menu) e testar"
echo -e "na tela real do seu monitor sem risco algum ao seu disco!\n"

echo -e "${YELLOW}Pontos de montagem FAT32 disponíveis no sistema:${NC}"
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT | grep -iE 'vfat|fat32' || true

echo ""
read -rp "Digite o caminho onde o pendrive está montado (ex: /media/$USER/PENDRIVE): " USB_MOUNT

if [[ ! -d "${USB_MOUNT}" ]]; then
    echo -e "${RED}[-] Diretório '${USB_MOUNT}' não encontrado.${NC}" >&2
    exit 1
fi

echo -e "\n[*] Criando estrutura UEFI no pendrive..."
mkdir -p "${USB_MOUNT}/EFI/BOOT"
mkdir -p "${USB_MOUNT}/EFI/BOOT/theme"

echo "[*] Copiando binário e tema..."
cp -f "${SCRIPT_DIR}/refind_x64.efi" "${USB_MOUNT}/EFI/BOOT/BOOTX64.EFI"
cp -f "${SCRIPT_DIR}/refind.conf" "${USB_MOUNT}/EFI/BOOT/refind.conf"
cp -rf "${SCRIPT_DIR}/theme/"* "${USB_MOUNT}/EFI/BOOT/theme/"

sync
echo -e "\n${GREEN}==========================================================${NC}"
echo -e "${GREEN}  ⚛️ Pendrive de Teste UEFI Criado com Sucesso!${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo -e "Como testar:"
echo -e "1. Reinicie seu computador."
echo -e "2. Pressione a tecla de Boot Menu da sua placa-mãe (geralmente F12, F11, F8 ou F2)."
echo -e "3. Selecione o seu pendrive na lista UEFI."
echo -e "4. O Nexus Dual Boot vai carregar com o tema Nanquim no seu monitor!"
echo -e "5. Ao terminar, basta desligar ou reiniciar normalmente.\n"
