@echo off
title Tower Defense: Forest Trail - MetaMask Sepolia Bridge
cd /d "%~dp0blockchain"
echo Menjalankan Web3 MetaMask Companion Bridge di http://127.0.0.1:3845 ...
echo Jangan tutup jendela ini selama bermain dengan MetaMask Sepolia.
echo.
node bridge/server.js
pause
