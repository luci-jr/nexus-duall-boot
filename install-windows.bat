@echo off
:: ==============================================================================
:: ◈ NEXUS DUAL BOOT ◈ — Instalador Oficial para Windows 10 e 11
:: Executa em modo Administrador, monta a partição EFI e registra o seletor UEFI.
:: ==============================================================================
chcp 65001 >nul
cls
echo ==========================================================
echo   ◈ NEXUS DUAL BOOT ◈ — Instalador para Windows UEFI
echo ==========================================================
echo.

:: 1. Verifica permissões de Administrador
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo [-] Erro: Este script precisa ser executado como Administrador.
    echo     Clique com o botao direito no arquivo e escolha:
    echo     "Executar como administrador"
    echo.
    pause
    exit /b 1
)

set SCRIPT_DIR=%~dp0
set ESP_DRIVE=S:
set TARGET_DIR=%ESP_DRIVE%\EFI\nexus-duall-boot

echo [+] Permissoes de Administrador confirmadas.
echo [*] Montando particao EFI do sistema em %ESP_DRIVE%...

:: 2. Monta partição EFI
mountvol %ESP_DRIVE% /s
if not exist %ESP_DRIVE%\EFI (
    echo [-] Falha ao montar a particao EFI do Windows.
    echo     Certifique-se de que sua placa-mae esta em modo UEFI (GPT).
    pause
    exit /b 1
)

echo [+] Particao EFI montada com sucesso em %ESP_DRIVE%.
echo [*] Criando diretorio de destino: %TARGET_DIR%...
if not exist "%TARGET_DIR%\theme" mkdir "%TARGET_DIR%\theme"

:: 3. Copia binário oficial UEFI
echo [*] Copiando binario refind_x64.efi...
copy /y "%SCRIPT_DIR%refind_x64.efi" "%TARGET_DIR%\refind_x64.efi" >nul

:: 4. Copia o tema completo e assets
echo [*] Copiando tema Nanquim modular...
xcopy /s /e /y "%SCRIPT_DIR%theme\*" "%TARGET_DIR%\theme\" >nul

:: 5. Copia e ajusta a configuracao
echo [*] Configurando refind.conf para caminhos da particao EFI...
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "(Get-Content '%SCRIPT_DIR%refind.conf') -replace '/EFI/BOOT/theme', '/EFI/nexus-duall-boot/theme' | Set-Content '%TARGET_DIR%\refind.conf'"

:: 6. Faz backup da configuracao anterior do BCD
echo [*] Criando ponto de restauracao no BCD do Windows...
bcdedit /export "%SCRIPT_DIR%bcd_backup_nexus.bcd" >nul 2>&1

:: 7. Registra Nexus Dual Boot como Boot Manager principal
echo [*] Registrando Nexus Dual Boot no gerenciador UEFI da placa-mae...
bcdedit /set {bootmgr} path \EFI\nexus-duall-boot\refind_x64.efi >nul
if %errorLevel% neq 0 (
    echo [-] Alerta ao atualizar {bootmgr} via BCD. Tentando criar entrada dedicada...
    for /f "tokens=2 delims={}" %%i in ('bcdedit /copy {bootmgr} /d "Nexus Dual Boot"') do set NEW_GUID={%%i}
    if defined NEW_GUID (
        bcdedit /set %NEW_GUID% path \EFI\nexus-duall-boot\refind_x64.efi >nul
        bcdedit /set {fwbootmgr} displayorder %NEW_GUID% /addfirst >nul
    )
)

:: 8. Desmonta a partição EFI por segurança
echo [*] Desmontando particao EFI...
mountvol %ESP_DRIVE% /d

echo.
echo ==========================================================
echo   ⚛️ SUCESSO! Nexus Dual Boot instalado no Windows.
echo ==========================================================
echo.
echo   Na proxima vez que reiniciares o computador:
echo   1. O Nexus Dual Boot vai abrir com o tema Zen Nanquim.
echo   2. O Windows 11/10 sera reconhecido automaticamente.
echo   3. Quando instalares qualquer Linux no futuro (Ubuntu, Fedora,
echo      Mint, Arch, Pop!_OS), ele sera adicionado sem configuracao!
echo.
echo   Para reverter futuramente, basta executar: uninstall-windows.bat
echo.
pause
