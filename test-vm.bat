@echo off
:: ==============================================================================
:: ◈ NEXUS DUAL BOOT ◈ — Simulador Visual em VM para Windows (QEMU + OVMF)
:: Testa a tela, resolução nativa, wallpaper e ícones sem instalar nada no PC.
:: ==============================================================================
chcp 65001 >nul
cls
setlocal enabledelayedexpansion

set SCRIPT_DIR=%~dp0
set VM_DIR=%SCRIPT_DIR%vm
set TEMP_VARS=%TEMP%\OVMF_VARS_nexus_%RANDOM%.fd

echo ==========================================================
echo   ◈ NEXUS DUAL BOOT ◈ — Simulador Visual UEFI (Windows)
echo ==========================================================
echo.

:: 1. Procura executável do QEMU
set QEMU_BIN=
where qemu-system-x86_64.exe >nul 2>&1
if %errorLevel% equ 0 (
    for /f "delims=" %%i in ('where qemu-system-x86_64.exe') do set QEMU_BIN=%%i
)

if not defined QEMU_BIN (
    if exist "C:\Program Files\qemu\qemu-system-x86_64.exe" (
        set QEMU_BIN=C:\Program Files\qemu\qemu-system-x86_64.exe
    ) else if exist "C:\Program Files (x86)\qemu\qemu-system-x86_64.exe" (
        set QEMU_BIN=C:\Program Files (x86)\qemu\qemu-system-x86_64.exe
    ) else if exist "%LOCALAPPDATA%\Programs\qemu\qemu-system-x86_64.exe" (
        set QEMU_BIN=%LOCALAPPDATA%\Programs\qemu\qemu-system-x86_64.exe
    )
)

:: 2. Se não encontrar o QEMU, oferece opções fáceis
if not defined QEMU_BIN (
    echo [-] O QEMU não foi encontrado instalado no seu Windows.
    echo.
    echo   Como você deseja testar o Nexus Dual Boot agora?
    echo.
    echo   [1] Instalar o QEMU automaticamente via winget (1 clique)
    echo   [2] Abrir Simulador Interativo Web (preview-theme.html - Zero instalação)
    echo   [3] Criar Pendrive de Teste UEFI (create-live-usb.bat - Testa no PC real)
    echo   [4] Sair
    echo.
    set /p OPT="Escolha uma opção [1-4]: "

    if "!OPT!"=="1" (
        echo.
        echo [*] Instalando QEMU oficial via winget...
        winget install -e --id SoftwareFreedomConservancy.QEMU --accept-package-agreements --accept-source-agreements
        if exist "C:\Program Files\qemu\qemu-system-x86_64.exe" (
            set QEMU_BIN=C:\Program Files\qemu\qemu-system-x86_64.exe
        ) else (
            echo.
            echo [+] QEMU instalado! Por favor, feche e abra novamente este script.
            pause
            exit /b 0
        )
    ) else if "!OPT!"=="2" (
        echo [*] Abrindo Simulador Interativo no navegador...
        start "" "%SCRIPT_DIR%preview-theme.html"
        exit /b 0
    ) else if "!OPT!"=="3" (
        call "%SCRIPT_DIR%create-live-usb.bat"
        exit /b 0
    ) else (
        exit /b 0
    )
)

echo [+] Binário QEMU encontrado: "%QEMU_BIN%"

:: 3. Valida se os arquivos de firmware e disco existem
if not exist "%VM_DIR%\disk.img" (
    echo [-] Erro: Arquivo de disco "%VM_DIR%\disk.img" não encontrado.
    pause
    exit /b 1
)

if not exist "%VM_DIR%\OVMF_CODE.fd" (
    echo [-] Erro: Firmware UEFI "%VM_DIR%\OVMF_CODE.fd" não encontrado.
    pause
    exit /b 1
)

:: Cria cópia temporária do arquivo de variáveis NVRAM
copy /y "%VM_DIR%\OVMF_VARS.fd" "%TEMP_VARS%" >nul

echo.
echo ==========================================================
echo   🚀 INICIANDO MÁQUINA VIRTUAL DE TESTE (QEMU UEFI)
echo   Dica: Use as setas do teclado para navegar e Enter para testar.
echo   Feche a janela do QEMU quando quiser encerrar o teste.
echo ==========================================================
echo.

"%QEMU_BIN%" -name "Nexus Dual Boot - Simulador Visual" ^
  -machine q35 -accel tcg -m 512 -smp 2 ^
  -drive if=pflash,format=raw,readonly=on,file="%VM_DIR%\OVMF_CODE.fd" ^
  -drive if=pflash,format=raw,file="%TEMP_VARS%" ^
  -drive if=virtio,format=raw,snapshot=on,file="%VM_DIR%\disk.img" ^
  -vga std -nic none -no-reboot

if exist "%TEMP_VARS%" del /f /q "%TEMP_VARS%" >nul 2>&1
echo [+] Teste encerrado com sucesso.
