@echo off
:: ==============================================================================
:: ◈ NEXUS DUAL BOOT ◈ — Criador de Pendrive de Teste UEFI (Windows)
:: Permite testar o seletor visual no seu PC real antes de instalar no disco.
:: ==============================================================================
chcp 65001 >nul
cls
echo ==========================================================
echo   ◈ NEXUS DUAL BOOT ◈ — Criador de Pendrive de Teste UEFI
echo ==========================================================
echo.
echo Este script copia o Nexus Dual Boot para um pendrive FAT32.
echo Voce podera reiniciar o PC, apertar F12 (Boot Menu) e testar
echo na tela real do seu monitor sem risco algum ao seu disco!
echo.

set SCRIPT_DIR=%~dp0
set /p USB_LETTER="Digite a letra da unidade do pendrive (ex: E: ou F:): "

if not exist "%USB_LETTER%\" (
    echo [-] Unidade %USB_LETTER% nao encontrada. Verifique se o pendrive esta inserido.
    pause
    exit /b 1
)

echo.
echo [*] Criando estrutura UEFI em %USB_LETTER%\EFI\BOOT...
if not exist "%USB_LETTER%\EFI\BOOT\theme" mkdir "%USB_LETTER%\EFI\BOOT\theme"

echo [*] Copiando arquivos de boot...
copy /y "%SCRIPT_DIR%refind_x64.efi" "%USB_LETTER%\EFI\BOOT\BOOTX64.EFI" >nul
copy /y "%SCRIPT_DIR%refind.conf" "%USB_LETTER%\EFI\BOOT\refind.conf" >nul
xcopy /s /e /y "%SCRIPT_DIR%theme\*" "%USB_LETTER%\EFI\BOOT\theme\" >nul

echo.
echo ==========================================================
echo   ⚛️ Pendrive de Teste UEFI Criado com Sucesso!
echo ==========================================================
echo Como testar:
echo 1. Reinicie seu computador.
echo 2. Pressione a tecla de Boot Menu (geralmente F12, F11, F8 ou F2).
echo 3. Selecione o seu pendrive na lista UEFI.
echo 4. O Nexus Dual Boot vai carregar com o tema Nanquim no seu monitor!
echo.
pause
