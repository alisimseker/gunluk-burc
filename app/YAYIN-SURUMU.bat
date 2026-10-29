@echo off
chcp 65001 >nul
title Burc Atlasi - Google Play yayin surumu
set "PATH=C:\src\flutter\bin;C:\src\git\cmd;%PATH%"
if not exist "%~dp0app\gunluk_burc\android\key.properties" (
  echo Once IMZA-ANAHTARI-OLUSTUR.bat calistirilmali.
  pause
  exit /b
)
echo.
echo  Imza anahtarinin SIFRESINI yaz ve Enter'a bas:
set /p BURC_KEY_PASSWORD=Sifre: 
cls
echo Yayin surumu hazirlaniyor (5-10 dakika), pencereyi kapatmayin...
cd /d "%~dp0app"
call dart setup.dart > "%~dp0yayin-log.txt" 2>&1
cd /d "%~dp0app\gunluk_burc"
call flutter build appbundle --release >> "%~dp0yayin-log.txt" 2>&1
set "BURC_KEY_PASSWORD="
if exist "build\app\outputs\bundle\release\app-release.aab" (
  copy /y "build\app\outputs\bundle\release\app-release.aab" "%~dp0BurcAtlasi-yayin.aab" >nul
  echo.
  echo  HAZIR: %~dp0BurcAtlasi-yayin.aab
  echo  Bu dosyayi Play Console'a yukleyeceksin.
) else (
  echo.
  echo  Bir sorun cikti. yayin-log.txt dosyasina bakilacak.
)
echo TAMAM> "%~dp0yayin-bitti.txt"
pause
