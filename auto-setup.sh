#!/usr/bin/env bash
# ==============================================================================
# ◈ NEXUS DUAL BOOT ◈ — Auto-Discovery & Configurator Universal
# Detecta Ubuntu 22.04/24.04/26.04, Fedora, CachyOS, Arch, Mint, Pop!_OS, Debian
# Detecta Windows 10/11 Pro/Home e compila o refind.conf de alta fidelidade
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}  ◈ NEXUS DUAL BOOT ◈ — Auto-Discovery & Configurator${NC}"
echo -e "${BLUE}==========================================================${NC}"
echo -e "\n${GREEN}[*] Executando motor de análise profunda de hardware e SOs...${NC}"

# Executa o motor Python de detecção
python3 "${SCRIPT_DIR}/scripts/detect_os.py"

echo -e "\n${BLUE}==========================================================${NC}"
echo -e "  Configuração gerada com sucesso em: ${CYAN}${SCRIPT_DIR}/refind.conf${NC}"
echo -e "  O que você deseja fazer agora?"
echo -e "  ${GREEN}[1] Testar no Simulador em VM (QEMU 100% seguro)${NC}"
echo -e "  ${YELLOW}[2] Instalar no Disco Real da Máquina (Requer sudo)${NC}"
echo -e "  [3] Sair"
echo -e "${BLUE}==========================================================${NC}"
read -rp "Escolha uma opção [1-3]: " opt

case "${opt}" in
    1)
        bash "${SCRIPT_DIR}/test-vm.sh"
        ;;
    2)
        sudo bash "${SCRIPT_DIR}/install.sh"
        ;;
    *)
        echo "Operação finalizada."
        ;;
esac
