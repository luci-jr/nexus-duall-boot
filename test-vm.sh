#!/usr/bin/env bash
# ==============================================================================
# ⚛️ Nexus Dual Boot — Simulador Visual em VM (QEMU + OVMF)
# Testa a tela, resolução nativa, wallpaper e ícones antes de tocar no hardware.
# ==============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
VM_DIR="${SCRIPT_DIR}/vm"

echo "=========================================================="
echo "  ⚛️ Nexus Dual Boot — Preparando Teste em VM"
echo "=========================================================="

# 1. Checa se o pacote refind está instalado
REFIND_BIN=""
for candidate in \
    "/usr/share/refind/refind/refind_x64.efi" \
    "/usr/share/refind/refind_x64.efi" \
    "/usr/lib/refind/refind_x64.efi" \
    "${SCRIPT_DIR}/refind_x64.efi" \
    "/boot/efi/EFI/refind/refind_x64.efi"; do
    if [[ -f "${candidate}" ]]; then
        REFIND_BIN="${candidate}"
        break
    fi
done

if [[ -z "${REFIND_BIN}" ]]; then
    echo "[*] O pacote 'refind' oficial precisa estar instalado."
    echo "    Instalando via apt (pode pedir sua senha sudo)..."
    sudo apt-get update -qq && sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq refind qemu-system-x86 qemu-system-gui ovmf mtools dosfstools gdisk
    for candidate in \
        "/usr/share/refind/refind/refind_x64.efi" \
        "/usr/share/refind/refind_x64.efi" \
        "/usr/lib/refind/refind_x64.efi"; do
        if [[ -f "${candidate}" ]]; then
            REFIND_BIN="${candidate}"
            break
        fi
    done
fi

if [[ ! -f "${REFIND_BIN}" ]]; then
    echo "[-] Não foi possível encontrar refind_x64.efi." >&2
    exit 1
fi

echo "[+] Binário oficial rEFInd: ${REFIND_BIN}"

# 2. Prepara estrutura temporária da ESP virtual
rm -rf "${VM_DIR}"
mkdir -p "${VM_DIR}/esp/EFI/BOOT/theme" "${VM_DIR}/esp/EFI/ubuntu" "${VM_DIR}/esp/EFI/Microsoft/Boot"

echo "[*] Montando arquivos do tema modular e configuração..."
cp -f "${REFIND_BIN}" "${VM_DIR}/esp/EFI/BOOT/BOOTX64.EFI"
cp -f "${SCRIPT_DIR}/refind.conf" "${VM_DIR}/esp/EFI/BOOT/refind.conf"
cp -rf "${SCRIPT_DIR}/theme/"* "${VM_DIR}/esp/EFI/BOOT/theme/"

# 3. Cria loaders de teste para Ubuntu e Windows
echo "[*] Gerando mini-loaders de demonstração..."
for os in ubuntu windows; do
  cat > "${VM_DIR}/${os}.cfg" <<CFG_EOF
set timeout=0
set default=0
terminal_output console
menuentry '>>> ${os^^} - Loader de Teste Alcancado com Sucesso! <<<' { true; }
menuentry 'Retornar ao menu Nexus Dual Boot' { exit; }
CFG_EOF
  if [[ "${os}" == "ubuntu" ]]; then
    grub-mkstandalone -O x86_64-efi --locales='' --fonts='' \
      -o "${VM_DIR}/esp/EFI/ubuntu/shimx64.efi" "boot/grub/grub.cfg=${VM_DIR}/${os}.cfg"
  else
    grub-mkstandalone -O x86_64-efi --locales='' --fonts='' \
      -o "${VM_DIR}/esp/EFI/Microsoft/Boot/bootmgfw.efi" "boot/grub/grub.cfg=${VM_DIR}/${os}.cfg"
  fi
done

# 4. Constrói imagem de disco virtual UEFI de 132MB
echo "[*] Construindo disco virtual de teste (132MB)..."
truncate -s 128M "${VM_DIR}/esp.img"
mkfs.vfat -F 32 -n NEXUS_BOOT "${VM_DIR}/esp.img" >/dev/null
mcopy -s -i "${VM_DIR}/esp.img" "${VM_DIR}/esp/EFI" ::/

truncate -s 132M "${VM_DIR}/disk.img"
sgdisk --clear --new=1:2048:+128M --typecode=1:ef00 --change-name=1:NEXUS_BOOT "${VM_DIR}/disk.img" >/dev/null
dd if="${VM_DIR}/esp.img" of="${VM_DIR}/disk.img" bs=1M seek=1 conv=notrunc status=none

OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.fd"
cp /usr/share/OVMF/OVMF_VARS_4M.fd "${VM_DIR}/OVMF_VARS.fd"

echo "=========================================================="
echo "  🚀 INICIANDO MÁQUINA VIRTUAL DE TESTE (QEMU)"
echo "  Dica: Use as setas do teclado para navegar e Enter para testar"
echo "  Feche a janela do QEMU quando quiser encerrar o teste."
echo "=========================================================="

# Detecta resolução nativa do monitor
RES_X=2560
RES_Y=1080
if command -v xrandr >/dev/null 2>&1 && [[ -n "${DISPLAY:-}" ]]; then
    XR_RES=$(xrandr --current 2>/dev/null | grep -oP '\d{3,4}x\d{3,4}(?=\s+\d+[\.\d]*\*)' | head -n1 || true)
    if [[ -n "${XR_RES}" ]]; then
        RES_X="${XR_RES%x*}"
        RES_Y="${XR_RES#*x}"
    fi
fi

qemu-system-x86_64 -name 'Nexus Dual Boot - Simulador Visual' \
  -machine q35 -accel tcg -m 512 -smp 2 \
  -drive if=pflash,format=raw,readonly=on,file="${OVMF_CODE}" \
  -drive if=pflash,format=raw,file="${VM_DIR}/OVMF_VARS.fd" \
  -drive if=virtio,format=raw,snapshot=on,file="${VM_DIR}/disk.img" \
  -vga none -device "bochs-display,xres=${RES_X},yres=${RES_Y}" \
  -nic none -no-reboot -display gtk,zoom-to-fit=on
