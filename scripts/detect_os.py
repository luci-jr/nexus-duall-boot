#!/usr/bin/env python3
# ==============================================================================
# ◈ NEXUS DUAL BOOT ◈ — Motor de Detecção Profunda de SOs e Versões
# Detecta Ubuntu 22.04/24.04/26.04, Fedora, CachyOS, Arch, Mint, Pop!_OS, Debian
# Detecta Windows 10/11 Pro/Home e compila o refind.conf de alta fidelidade
# ==============================================================================
import os
import sys
import glob
import re
import json
import subprocess

def detect_resolution():
    res = ""
    # 1. Tenta xrandr se em sessão gráfica
    if os.environ.get("DISPLAY"):
        try:
            out = subprocess.check_output(["xrandr", "--current"], stderr=subprocess.DEVNULL, text=True)
            m = re.search(r'(\d{3,4})x(\d{3,4})\s+\d+[\.\d]*\*', out)
            if m:
                res = f"{m.group(1)} {m.group(2)}"
        except Exception:
            pass
            
    # 2. Fallback via DRM / sysfs
    if not res:
        for mode_file in glob.glob("/sys/class/drm/*/modes"):
            try:
                with open(mode_file) as f:
                    first = f.readline().strip()
                    if "x" in first:
                        res = first.replace("x", " ")
                        break
            except Exception:
                pass
                
    return res if res else "2560 1080"

def detect_esp_mount():
    for candidate in ["/boot/efi", "/efi", "/boot/EFI", "/boot"]:
        if os.path.isdir(os.path.join(candidate, "EFI")):
            return candidate
            
    try:
        out = subprocess.check_output(["findmnt", "-n", "-o", "TARGET", "-t", "vfat"], stderr=subprocess.DEVNULL, text=True)
        for line in out.splitlines():
            line = line.strip()
            if os.path.isdir(os.path.join(line, "EFI")):
                return line
    except Exception:
        pass
        
    return "/boot/efi"

def detect_current_linux_info():
    info = {"id": "linux", "name": "Linux", "pretty": "Linux", "version": ""}
    if os.path.exists("/etc/os-release"):
        with open("/etc/os-release") as f:
            for line in f:
                line = line.strip()
                if line.startswith("PRETTY_NAME="):
                    info["pretty"] = line.split("=", 1)[1].strip("\"'")
                elif line.startswith("ID="):
                    info["id"] = line.split("=", 1)[1].strip("\"'").lower()
                elif line.startswith("VERSION_ID="):
                    info["version"] = line.split("=", 1)[1].strip("\"'")

    # Formatações elegantes e padronizadas
    pretty = info["pretty"]
    m = re.match(r'(Ubuntu\s+\d+\.\d+)(\.\d+)?(\s+LTS)?', pretty, re.I)
    if m:
        pretty = f"{m.group(1)}{m.group(3) or ''}"
    elif "fedora" in info["id"]:
        m = re.search(r'Fedora(?:\s+Linux)?\s+(\d+)', pretty, re.I)
        pretty = f"Fedora {m.group(1)}" if m else "Fedora Linux"
    elif "debian" in info["id"]:
        m = re.search(r'Debian(?:\s+GNU/Linux)?\s+(\d+)', pretty, re.I)
        pretty = f"Debian {m.group(1)}" if m else "Debian Linux"
    elif "cachyos" in info["id"]:
        pretty = "CachyOS"
    elif "arch" in info["id"]:
        pretty = "Arch Linux"
    elif "mint" in info["id"]:
        m = re.search(r'Linux\s+Mint\s+(\d+(?:\.\d+)?)', pretty, re.I)
        pretty = f"Linux Mint {m.group(1)}" if m else "Linux Mint"
    elif "pop" in info["id"]:
        m = re.search(r'Pop!_OS\s+(\d+\.\d+)', pretty, re.I)
        pretty = f"Pop!_OS {m.group(1)}" if m else "Pop!_OS"

    info["pretty"] = pretty
    return info

def detect_windows_version(esp_dir):
    win_label = "Windows 11"
    
    # 1. Verifica BCD na partição EFI (independe de NTFS e BitLocker)
    bcd_path = os.path.join(esp_dir, "EFI", "Microsoft", "Boot", "BCD")
    if os.path.exists(bcd_path):
        try:
            with open(bcd_path, "rb") as f:
                bcd_data = f.read()
                for v in ["11", "10", "8.1", "8", "7"]:
                    if f"Windows {v}".encode("utf-16le") in bcd_data:
                        win_label = f"Windows {v}"
                        break
        except Exception:
            pass

    # 2. Tenta aprofundar se houver partição NTFS montada ou registro legível
    edition = ""
    try:
        out = subprocess.check_output(["lsblk", "-o", "FSTYPE,MOUNTPOINT", "-n"], stderr=subprocess.DEVNULL, text=True)
        for line in out.splitlines():
            parts = line.strip().split()
            if len(parts) >= 2 and parts[0].lower() in ["ntfs", "fuseblk"]:
                mnt = parts[1]
                soft_hive = os.path.join(mnt, "Windows", "System32", "config", "SOFTWARE")
                if os.path.exists(soft_hive):
                    try:
                        with open(soft_hive, "rb") as sf:
                            chunk = sf.read(4 * 1024 * 1024)
                            if b"Professional" in chunk:
                                edition = "Pro"
                            elif b"CoreSingleLanguage" in chunk or b"Core" in chunk:
                                edition = "Home"
                            elif b"Enterprise" in chunk:
                                edition = "Enterprise"
                                
                            m_prod = re.search(b"(Windows\\s+1[01]\\s+(?:Pro|Home|Enterprise))", chunk)
                            if m_prod:
                                win_label = m_prod.group(1).decode("ascii", errors="ignore")
                                edition = ""
                                break
                    except Exception:
                        pass
    except Exception:
        pass

    if edition and not any(e in win_label for e in ["Pro", "Home", "Enterprise"]):
        win_label = f"{win_label} {edition}"

    return win_label

def scan_all_os(esp_dir):
    systems = []
    current_linux = detect_current_linux_info()
    
    distro_defs = [
        {"id": "ubuntu", "dir": "ubuntu", "shim": "shimx64.efi", "grub": "grubx64.efi", "icon": "ubuntu.png", "default_name": "Ubuntu Linux"},
        {"id": "fedora", "dir": "fedora", "shim": "shimx64.efi", "grub": "grubx64.efi", "icon": "fedora.png", "default_name": "Fedora Linux"},
        {"id": "cachyos", "dir": "cachyos", "shim": "grubx64.efi", "grub": "systemd-bootx64.efi", "icon": "cachyos.png", "default_name": "CachyOS"},
        {"id": "arch", "dir": "arch", "shim": "grubx64.efi", "grub": "systemd-bootx64.efi", "icon": "arch.png", "default_name": "Arch Linux"},
        {"id": "mint", "dir": "linuxmint", "shim": "shimx64.efi", "grub": "grubx64.efi", "icon": "mint.png", "default_name": "Linux Mint"},
        {"id": "pop", "dir": "Pop_OS", "shim": "systemd-bootx64.efi", "grub": "grubx64.efi", "icon": "pop.png", "default_name": "Pop!_OS"},
        {"id": "debian", "dir": "debian", "shim": "shimx64.efi", "grub": "grubx64.efi", "icon": "debian.png", "default_name": "Debian GNU/Linux"},
    ]

    for d in distro_defs:
        d_dir = os.path.join(esp_dir, "EFI", d["dir"])
        if not os.path.isdir(d_dir):
            continue

        loader_rel = ""
        for loader in [d["shim"], d["grub"], "shimx64.efi", "grubx64.efi"]:
            if os.path.exists(os.path.join(d_dir, loader)):
                loader_rel = f"EFI/{d['dir']}/{loader}"
                break
                
        if not loader_rel:
            continue

        if d["id"] in current_linux["id"] or current_linux["id"] in d["id"]:
            name = current_linux["pretty"]
        else:
            name = d["default_name"]

        systems.append({
            "name": name,
            "loader": loader_rel,
            "icon": d["icon"],
            "id": d["id"]
        })

    win_loader = os.path.join(esp_dir, "EFI", "Microsoft", "Boot", "bootmgfw.efi")
    if os.path.exists(win_loader):
        win_title = detect_windows_version(esp_dir)
        systems.append({
            "name": win_title,
            "loader": "EFI/Microsoft/Boot/bootmgfw.efi",
            "icon": "windows.png",
            "id": "windows"
        })

    if not systems:
        linux_name = current_linux["pretty"] if current_linux["pretty"] != "Linux" else "Ubuntu 26.04 LTS"
        systems.append({
            "name": linux_name,
            "loader": "EFI/ubuntu/shimx64.efi",
            "icon": "ubuntu.png",
            "id": "ubuntu"
        })
        systems.append({
            "name": "Windows 11 Pro",
            "loader": "EFI/Microsoft/Boot/bootmgfw.efi",
            "icon": "windows.png",
            "id": "windows"
        })

    return systems

def generate_refind_conf(resolution, systems, out_file):
    lines = [
        "# ==============================================================================",
        "# ◈ NEXUS DUAL BOOT ◈ — Seletor UEFI Oficial (Nexus Ecosystem)",
        f"# Resolução: {resolution} | Timeout: 0 (Aguardando seleção manual)",
        "# Tema Ativo: Nanquim (Sumi-e Zen) — Multi-Distro & Windows Auto-Discovery",
        "# ==============================================================================",
        "timeout 0",
        "screensaver 0",
        "use_nvram false",
        "scanfor manual,external",
        f'default_selection "{systems[0]["name"]}"',
        f"resolution {resolution}" if resolution else "resolution 1920 1080",
        "",
        "banner theme/nanquim/background/background.png",
        "banner_scale fillscreen",
        "",
        "icons_dir theme/nanquim/icons",
        "big_icon_size 384",
        "small_icon_size 100",
        "selection_big theme/nanquim/ui/selection-big.png",
        "selection_small theme/nanquim/ui/selection-small.png",
        "",
        "# Interface Limpa: esconde setas e badges de disco",
        "hideui hints,arrows,badges",
        "",
        "# Exibe os 4 utilitarios oficiais centralizados (Desligar, Reiniciar, BIOS, Sair)",
        "showtools shutdown, reboot, firmware, exit, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync, gptsync",
        "",
        "# Bloqueia qualquer escaneamento externo residual",
        "dont_scan_tools shell,memtest,gdisk,apple_recovery,windows_recovery,mok_tool,about,hidden_tags,fwupdate,netboot,csr_rotate,install,bootorder",
        ""
    ]

    for sys_entry in systems:
        lines.append(f'menuentry "{sys_entry["name"]}" {{')
        lines.append(f'    loader /{sys_entry["loader"]}')
        lines.append(f'    icon /EFI/BOOT/theme/nanquim/os/{sys_entry["icon"]}')
        lines.append("}\n")

    with open(out_file, "w") as f:
        f.write("\n".join(lines))

if __name__ == "__main__":
    res = detect_resolution()
    esp = detect_esp_mount()
    systems = scan_all_os(esp)
    
    script_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    out_conf = os.path.join(script_dir, "refind.conf")
    generate_refind_conf(res, systems, out_conf)
    
    print(json.dumps({
        "resolution": res,
        "esp_mount": esp,
        "systems": systems,
        "conf_file": out_conf
    }, indent=2))
