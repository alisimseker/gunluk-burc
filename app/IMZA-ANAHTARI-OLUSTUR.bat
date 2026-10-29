@echo off
chcp 65001 >nul
title Burc Atlasi - Yayin imza anahtari olustur
set "KT=C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"
if not exist "%KT%" set "KT=keytool"
set "KS=%USERPROFILE%\burc-atlasi-yukleme-anahtari.jks"
if exist "%KS%" (
  echo Anahtar zaten var: %KS%
  echo Yenisini olusturmayin; eskisini kullanin.
  pause
  exit /b
)
echo.
echo  Google Play'e yukleme icin IMZA ANAHTARI olusturulacak.
echo  - Bir SIFRE belirleyeceksin (en az 6 karakter). Bunu UNUTMA ve bir yere not et.
echo  - Sifreyi yazarken ekranda gorunmez, bu normal.
echo  - Ad, sehir gibi sorulari doldurabilir ya da Enter ile gecebilirsin; sonunda "evet" icin  y  yaz.
echo.
"%KT%" -genkeypair -v -keystore "%KS%" -alias upload -keyalg RSA -keysize 2048 -validity 10000
if exist "%KS%" (
  echo storeFile=%KS:\=/%> "%~dp0app\gunluk_burc\android\key.properties"
  echo keyAlias=upload>> "%~dp0app\gunluk_burc\android\key.properties"
  echo.
  echo  TAMAM. Anahtar dosyasi: %KS%
  echo  BU DOSYAYI ve SIFREYI yedekle (USB bellek, Google Drive). Kaybolursa uygulama guncellenemez.
)
pause
