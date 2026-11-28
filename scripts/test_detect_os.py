#!/usr/bin/env python3
"""
Testes unitários para o motor de detecção do Nexus Dual Boot
"""
import unittest
import sys
import os
import tempfile
import shutil

# Adiciona o diretório de scripts ao path
sys.path.insert(0, os.path.dirname(__file__))
from detect_os import detect_current_linux_info, detect_windows_version


class TestDetectOS(unittest.TestCase):
    def setUp(self):
        self.test_dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.test_dir)

    def test_detect_current_linux_info_default(self):
        info = detect_current_linux_info()
        self.assertIn("id", info)
        self.assertIn("pretty", info)
        self.assertIsInstance(info["pretty"], str)

    def test_detect_windows_version_fallback(self):
        # Diretório vazio sem BCD deve retornar Windows 11 por padrão
        ver = detect_windows_version(self.test_dir)
        self.assertEqual(ver, "Windows 11")

    def test_detect_windows_version_with_mock_bcd(self):
        # Cria estrutura de BCD simulada
        boot_dir = os.path.join(self.test_dir, "EFI", "Microsoft", "Boot")
        os.makedirs(boot_dir, exist_ok=True)
        bcd_file = os.path.join(boot_dir, "BCD")
        
        # Simula BCD do Windows 10
        with open(bcd_file, "wb") as f:
            f.write(b"MOCK_HEADER_" + "Windows 10".encode("utf-16le") + b"_TRAILER")
            
        ver = detect_windows_version(self.test_dir)
        self.assertEqual(ver, "Windows 10")


if __name__ == "__main__":
    unittest.main()
