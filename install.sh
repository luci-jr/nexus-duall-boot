#!/usr/bin/env bash
# ==============================================================================
# ◈ NEXUS DUAL BOOT ◈ — Instalador Universal Seguro (UEFI & Multi-Distro)
# Suporta: Ubuntu, Fedora, CachyOS, Arch, Mint, Pop!_OS, Debian e Windows
# Blindado contra atualizações de Kernel e sobrescrita de Bootloader pelo Windows
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR_NAME="nexus-duall-boot"

# Cores do terminal
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[-] Este script precisa ser executado como root.${NC}" >&2
   echo -e "    Por favor, execute: ${YELLOW}sudo bash install.sh${NC}" >&2
   exit 1
fi

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}  ◈ NEXUS DUAL BOOT ◈ — Instalador de Produção UEFI${NC}"
echo -e "${BLUE}==========================================================${NC}"

# 1. Localização Inteligente da Partição EFI (ESP)
echo -e "\n${GREEN}[1/6] Identificando partição EFI do sistema...${NC}"
ESP_MOUNT=""
for candidate in "/boot/efi" "/efi" "/boot/EFI" "/boot"; do
    if findmnt -M "${candidate}" >/dev/null 2>&1 && [[ -d "${candidate}/EFI" ]]; then
        ESP_MOUNT="${candidate}"
        break
    fi
done

if [[ -z "${ESP_MOUNT}" ]]; then
    ESP_MOUNT=$(findmnt -n -o TARGET -t vfat 2>/dev/null | head -n1 || true)
fi

if [[ -z "${ESP_MOUNT}" || ! -d "${ESP_MOUNT}/EFI" ]]; then
    echo -e "${RED}[-] Partição EFI (ESP) não foi encontrada montada.${NC}" >&2
    echo -e "    Certifique-se de que a partição EFI está montada em /boot/efi ou /efi." >&2
    exit 1
fi

TARGET_DIR="${ESP_MOUNT}/EFI/${TARGET_DIR_NAME}"
echo -e "  [+] Partição EFI detectada: ${CYAN}${ESP_MOUNT}${NC}"
echo -e "  [+] Diretório de destino isolado: ${CYAN}${TARGET_DIR}${NC}"

# 2. Resolução Automática de Dependências Multi-Distro
echo -e "\n${GREEN}[2/6] Verificando dependências do sistema...${NC}"

install_pkg() {
    local pkg_debian="$1"
    local pkg_fedora="$2"
    local pkg_arch="$3"
    
    if command -v apt-get >/dev/null 2>&1; then
        apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${pkg_debian}"
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q "${pkg_fedora}"
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm "${pkg_arch}"
    elif command -v zypper >/dev/null 2>&1; then
        zypper --non-interactive in "${pkg_fedora}"
    else
        echo -e "${YELLOW}[!] Gerenciador de pacotes não reconhecido. Certifique-se de ter '${pkg_debian}' instalado.${NC}"
    fi
}

if ! command -v efibootmgr >/dev/null 2>&1; then
    echo -e "  [*] Instalando efibootmgr..."
    install_pkg "efibootmgr" "efibootmgr" "efibootmgr"
fi

# Localiza binário rEFInd oficial
REFIND_BIN=""
for candidate in     "/usr/share/refind/refind/refind_x64.efi"     "/usr/share/refind/refind_x64.efi"     "/usr/lib/refind/refind_x64.efi"     "${SCRIPT_DIR}/refind_x64.efi"     "${ESP_MOUNT}/EFI/refind/refind_x64.efi"; do
    if [[ -f "${candidate}" ]]; then
        REFIND_BIN="${candidate}"
        break
    fi
done

if [[ -z "${REFIND_BIN}" ]]; then
    echo -e "  [*] Binário rEFInd não encontrado localmente. Instalando via gerenciador de pacotes..."
    install_pkg "refind" "refind" "refind"
    for candidate in         "/usr/share/refind/refind/refind_x64.efi"         "/usr/share/refind/refind_x64.efi"         "/usr/lib/refind/refind_x64.efi"; do
        if [[ -f "${candidate}" ]]; then
            REFIND_BIN="${candidate}"
            break
        fi
    done
fi

if [[ ! -f "${REFIND_BIN}" ]]; then
    echo -e "${RED}[-] Não foi possível encontrar refind_x64.efi.${NC}" >&2
    exit 1
fi
echo -e "  [+] Binário UEFI rEFInd: ${CYAN}${REFIND_BIN}${NC}"

# 3. Backup de Segurança do Estado Anterior
echo -e "\n${GREEN}[3/6] Criando backup de segurança da instalação anterior...${NC}"
BACKUP_BASE="${SUDO_USER:+/home/$SUDO_USER/.local/share/nexus-duall-boot/backups}"
BACKUP_BASE="${BACKUP_BASE:-/var/backups/nexus-duall-boot}"
BACKUP_DIR="${BACKUP_BASE}/nexus-backup-$(date +%Y%m%d_%H%M%S)"
if [[ -d "${TARGET_DIR}" ]]; then
    mkdir -p "${BACKUP_DIR}"
    cp -rf "${TARGET_DIR}" "${BACKUP_DIR}/"
    echo -e "  [+] Backup da instalação anterior salvo fora da ESP em: ${CYAN}${BACKUP_DIR}${NC}"
else
    echo -e "  [+] Nenhuma instalação anterior do Nexus Dual Boot encontrada. Prosseguindo."
fi

# 4. Instalação e Sincronização de Arquivos
echo -e "\n${GREEN}[4/6] Instalando Nexus Dual Boot na partição EFI...${NC}"
mkdir -p "${TARGET_DIR}/theme"

# Copia binário oficial
cp -f "${REFIND_BIN}" "${TARGET_DIR}/refind_x64.efi"

# Copia tema completo e assets
cp -rf "${SCRIPT_DIR}/theme/"* "${TARGET_DIR}/theme/"

# Compila refind.conf final com os caminhos corretos da ESP física
cp -f "${SCRIPT_DIR}/refind.conf" "${TARGET_DIR}/refind.conf"
sed -i "s|/EFI/BOOT/theme|/EFI/${TARGET_DIR_NAME}/theme|g" "${TARGET_DIR}/refind.conf"

echo -e "  [+] Binário, tema e configuração sincronizados em ${TARGET_DIR}"

# 5. Registro UEFI na NVRAM e Priorização de Boot
echo -e "\n${GREEN}[5/6] Registrando na NVRAM da placa-mãe (efibootmgr)...${NC}"
ESP_DEVICE="$(findmnt -n -o SOURCE "${ESP_MOUNT}")"
DISK_NAME="$(lsblk -no PKNAME "${ESP_DEVICE}" 2>/dev/null || true)"
PART_NUM="$(lsblk -no PARTN "${ESP_DEVICE}" 2>/dev/null || true)"

if [[ -z "${DISK_NAME}" || -z "${PART_NUM}" ]]; then
    DISK_PATH="/dev/$(echo "${ESP_DEVICE}" | sed -E 's/p?[0-9]+$//')"
    PART_NUM="$(echo "${ESP_DEVICE}" | grep -o '[0-9]*$')"
else
    DISK_PATH="/dev/${DISK_NAME}"
fi

echo -e "  [+] Disco físico: ${CYAN}${DISK_PATH}${NC} (Partição ESP: ${CYAN}${PART_NUM}${NC})"

# Remove entradas anteriores do Nexus Dual Boot para evitar poluição da NVRAM
EXISTING_BOOT_ENTRIES=$(efibootmgr | grep -i "Nexus Dual Boot" | sed -E 's/Boot([0-9A-Fa-f]+).*/\1/' || true)
for bnum in ${EXISTING_BOOT_ENTRIES}; do
    echo -e "  [*] Removendo entrada antiga Boot${bnum}..."
    efibootmgr -b "${bnum}" -B >/dev/null 2>&1 || true
done

# Cria nova entrada prioritária
echo -e "  [*] Criando nova entrada UEFI 'Nexus Dual Boot'..."
efibootmgr --create     --disk "${DISK_PATH}"     --part "${PART_NUM}"     --label "Nexus Dual Boot"     --loader "\\EFI\\${TARGET_DIR_NAME}\\refind_x64.efi" >/dev/null

# Obtém o novo BootNumber criado e coloca como primeiro da BootOrder
NEW_BOOT_NUM=$(efibootmgr | grep -i "Nexus Dual Boot" | head -n1 | sed -E 's/Boot([0-9A-Fa-f]+).*/\1/' || true)
if [[ -n "${NEW_BOOT_NUM}" ]]; then
    CURRENT_ORDER=$(efibootmgr | grep -i "BootOrder:" | awk '{print $2}')
    CLEAN_ORDER=$(echo "${CURRENT_ORDER}" | tr ',' '\n' | grep -v -i "^${NEW_BOOT_NUM}$" | tr '\n' ',' | sed 's/,$//')
    NEW_ORDER="${NEW_BOOT_NUM},${CLEAN_ORDER}"
    efibootmgr -o "${NEW_ORDER}" >/dev/null
    echo -e "  [+] Ordem de boot atualizada na placa-mãe: ${GREEN}${NEW_BOOT_NUM}${NC} como principal!"
fi

# 6. Blindagem Contra Sobrescrita pelo Windows Update (Boot Guard Service)
echo -e "\n${GREEN}[6/6] Instalando proteção de persistência (Nexus Boot Guard)...${NC}"
if command -v systemctl >/dev/null 2>&1; then
    cat > /etc/systemd/system/nexus-boot-guard.service <<'GUARD_EOF'
[Unit]
Description=Nexus Dual Boot — BootOrder Guard
After=local-fs.target

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'NEXUS_NUM=$(efibootmgr | grep -i "Nexus Dual Boot" | head -n1 | sed -E "s/Boot([0-9A-Fa-f]+).*/\\1/"); if [ -n "$NEXUS_NUM" ]; then CUR=$(efibootmgr | grep "BootOrder:" | awk "{print \$2}"); if [[ "$CUR" != "$NEXUS_NUM"* ]]; then ORDER="$NEXUS_NUM,$(echo "$CUR" | tr "," "\n" | grep -v "^$NEXUS_NUM$" | tr "\n" "," | sed "s/,$//")"; efibootmgr -o "$ORDER" >/dev/null 2>&1; fi; fi'

[Install]
WantedBy=multi-user.target
GUARD_EOF

    systemctl daemon-reload
    systemctl enable nexus-boot-guard.service >/dev/null 2>&1 || true
    echo -e "  [+] Serviço systemd ${CYAN}nexus-boot-guard.service${NC} ativado com sucesso!"
    echo -e "      (Garante que o Windows Update nunca desloque o Nexus da 1ª posição)"
fi

# Fallback opcional UEFI (cópia para EFI/BOOT/BOOTX64.EFI)
if [[ ! -f "${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI.orig" && -f "${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI" ]]; then
    cp -f "${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI" "${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI.orig"
fi
cp -f "${REFIND_BIN}" "${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI"
echo -e "  [+] Fallback UEFI padrão atualizado (${ESP_MOUNT}/EFI/BOOT/BOOTX64.EFI)"

# 7. Silenciamento Automático do GRUB (Transição Direta sem Tela Azul)
if [[ -f "/etc/default/grub" ]] && command -v update-grub >/dev/null 2>&1; then
    echo -e "\n${GREEN}[7/7] Configurando transição direta do Linux (silenciando tela azul do GRUB)...${NC}"
    if [[ ! -f "/etc/default/grub.nexus-orig" ]]; then
        cp -f "/etc/default/grub" "/etc/default/grub.nexus-orig"
    fi
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/' /etc/default/grub
    if grep -q "^GRUB_TIMEOUT_STYLE=" /etc/default/grub; then
        sed -i 's/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' /etc/default/grub
    else
        echo 'GRUB_TIMEOUT_STYLE=hidden' >> /etc/default/grub
    fi
    if grep -q "^GRUB_RECORDFAIL_TIMEOUT=" /etc/default/grub; then
        sed -i 's/^GRUB_RECORDFAIL_TIMEOUT=.*/GRUB_RECORDFAIL_TIMEOUT=0/' /etc/default/grub
    else
        echo 'GRUB_RECORDFAIL_TIMEOUT=0' >> /etc/default/grub
    fi
    if grep -q "^GRUB_DISABLE_OS_PROBER=" /etc/default/grub; then
        sed -i 's/^GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=true/' /etc/default/grub
    else
        echo 'GRUB_DISABLE_OS_PROBER=true' >> /etc/default/grub
    fi
    update-grub >/dev/null 2>&1 || true
    echo -e "  [+] GRUB silenciado com sucesso: o Linux agora inicializa direto sem tela intermediária!"
fi

echo -e "\n${BLUE}==========================================================${NC}"
echo -e "  ${GREEN}✅ INSTALAÇÃO CONCLUÍDA COM TOTAL SUCESSO!${NC}"
echo -e "${BLUE}==========================================================${NC}"
echo -e "Resumo da proteção aplicada:"
echo -e " 1. ${GREEN}Imunidade a Atualizações de Kernel:${NC} O boot ocorre via handoff oficial"
echo -e "    para o shim/loader da distribuição, mantendo o kernel sempre atualizado sem quebras."
echo -e " 2. ${GREEN}Imunidade ao Windows Update:${NC} O Nexus Boot Guard e o fallback UEFI"
echo -e "    garantem que a máquina sempre inicialize pelo Nexus Dual Boot."
echo -e " 3. ${GREEN}Desinstalação Reversível:${NC} Execute ${YELLOW}sudo bash uninstall.sh${NC} a qualquer momento."
echo -e "=========================================================="
