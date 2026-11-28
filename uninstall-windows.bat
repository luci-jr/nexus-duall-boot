@echo off
:: ==============================================================================
:: ◈ NEXUS DUAL BOOT ◈ — Desinstalador Oficial para Windows 10 e 11
:: Restaura o Windows Boot Manager nativo e remove os arquivos da ESP.
:: ==============================================================================
chcp 65001 >nul
cls
echo ==========================================================
echo   ◈ NEXUS DUAL BOOT ◈ — Desinstalador Windows UEFI
echo ==========================================================
echo.

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [-] Erro: Este script precisa ser executado como Administrador.
    echo     Clique com o botao direito no arquivo e escolha:
    echo     "Executar como administrador"
    echo.
    pause
    exit /b 1
)

set ESP_DRIVE=S:
set TARGET_DIR=%ESP_DRIVE%\EFI\nexus-duall-boot

echo [*] Restaurando o Windows Boot Manager original...
bcdedit /set {bootmgr} path \EFI\Microsoft\Boot\bootmgfw.efi >nul

echo [*] Montando particao EFI em %ESP_DRIVE% para limpeza...
mountvol %ESP_DRIVE% /s

if exist "%TARGET_DIR%" (
    echo [*] Removendo arquivos do Nexus Dual Boot...
    rmdir /s /q "%TARGET_DIR%" >nul 2>&1
    echo [+] Arquivos removidos da particao EFI.
)

mountvol %ESP_DRIVE% /d
echo [+] Particao EFI desmontada com seguranca.

echo.
echo ==========================================================
echo   ⚛️ Desinstalacao concluida! O Windows Boot Manager nativo
echo   foi restaurado com sucesso.
echo ==========================================================
echo.
pause
