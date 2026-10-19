@echo off
REM ==============================================
REM Money Flow Mobile — Setup Script
REM Jalankan setelah Flutter SDK tersedia di PATH
REM ==============================================

echo ============================================
echo Money Flow Mobile — Setup
echo ============================================

REM Check Flutter
if exist "D:\flutter\bin" set "PATH=D:\flutter\bin;%PATH%"
echo [1/6] Memeriksa Flutter SDK...
where flutter >nul 2>nul
if errorlevel 1 (
    echo ERROR: Flutter tidak ditemukan di PATH!
    echo Pastikan Flutter SDK sudah terinstall dan ditambahkan ke PATH.
    echo Download: https://docs.flutter.dev/get-started/install
    exit /b 1
)
call flutter --version

REM Navigate to mobile directory
cd /d "%~dp0mobile"

REM Check if Flutter project already exists
if exist "pubspec.yaml" (
    echo [2/6] Proyek Flutter sudah ada, melewati langkah inisialisasi...
) else (
    echo.
    echo [2/6] Membuat proyek Flutter...
    call flutter create --org com.moneyflow --project-name money_flow --platforms android .
    if errorlevel 1 (
        echo ERROR: Gagal membuat proyek Flutter!
        exit /b 1
    )
)

REM Get dependencies
echo.
echo [3/6] Mengunduh dependensi...
call flutter pub get
if errorlevel 1 (
    echo ERROR: Gagal mengunduh dependensi!
    exit /b 1
)

REM Run Drift code generation
echo.
echo [4/6] Menjalankan code generation (Drift)...
call dart run build_runner build --delete-conflicting-outputs
if errorlevel 1 (
    echo WARNING: Code generation gagal. Coba jalankan ulang setelah fix error.
)

REM Run analyzer
echo.
echo [5/6] Menjalankan Dart analyzer...
call flutter analyze
echo.

REM Run tests
echo.
echo [6/6] Menjalankan unit tests...
call flutter test
echo.

echo ============================================
echo Setup selesai!
echo.
echo Langkah berikutnya:
echo   1. cd mobile
echo   2. flutter run (untuk menjalankan di device/emulator)
echo   3. flutter build apk --release (untuk build APK Release)
echo   4. flutter build apk --debug (untuk build APK Debug)
echo ============================================
