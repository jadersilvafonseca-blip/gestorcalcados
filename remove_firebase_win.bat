@echo off
REM ============================================================
REM remove_firebase_win.bat - Remove Firebase from a Flutter app
REM Usage: Double-click or run in a terminal from the project root
REM ============================================================
setlocal ENABLEDELAYEDEXPANSION

echo.
echo  ============================================================
echo   Removing Firebase from this Flutter project (Windows)
echo  ============================================================
echo.

REM --- Sanity check: pubspec.yaml must exist in current dir
if not exist "pubspec.yaml" (
  echo [ERROR] This does not look like a Flutter project root (pubspec.yaml not found).
  echo         Open a terminal in your project's root folder and run this script again.
  exit /b 1
)

REM --- Step 1: Remove common Firebase packages (ignore errors if not present)
set PACKAGES=firebase_core cloud_firestore firebase_auth firebase_storage firebase_messaging firebase_analytics firebase_crashlytics firebase_remote_config firebase_performance firebase_app_check firebase_database firebase_dynamic_links

for %%P in (%PACKAGES%) do (
  echo - Trying to remove package: %%P
  call :pubremove %%P
)

echo.
echo - Running flutter pub get ...
flutter pub get 1>nul 2>nul
if errorlevel 1 (
  echo   [WARN] flutter pub get encountered issues. Continuing...
) else (
  echo   OK
)

REM --- Step 2: Android cleanup
echo.
echo  -- ANDROID cleanup --

if exist "android\app\google-services.json" (
  echo - Deleting android\app\google-services.json
  del /f /q "android\app\google-services.json"
) else (
  echo - google-services.json not found (OK)
)

REM Remove classpath 'com.google.gms:google-services' from android/build.gradle
if exist "android\build.gradle" (
  echo - Cleaning android\build.gradle (google services classpath)
  powershell -NoProfile -Command "(Get-Content 'android/build.gradle') ^
    -notmatch 'com\.google\.gms:google-services' | Set-Content 'android/build.gradle'"
) else (
  echo - android\build.gradle not found (OK)
)

REM Remove apply plugin: 'com.google.gms.google-services' from android/app/build.gradle
if exist "android\app\build.gradle" (
  echo - Cleaning android\app\build.gradle (apply google services)
  powershell -NoProfile -Command "(Get-Content 'android/app/build.gradle') ^
    -notmatch 'com\.google\.gms\.google-services' ^
    -notmatch 'apply plugin:\s*''com\.google\.gms\.google-services''' | Set-Content 'android/app/build.gradle'"
) else (
  echo - android\app\build.gradle not found (OK)
)

REM --- Step 3: iOS cleanup
echo.
echo  -- iOS cleanup --

if exist "ios\Runner\GoogleService-Info.plist" (
  echo - Deleting ios\Runner\GoogleService-Info.plist
  del /f /q "ios\Runner\GoogleService-Info.plist"
) else (
  echo - iOS GoogleService-Info.plist not found (OK)
)

REM Remove Firebase imports/configure lines from AppDelegate (Swift or Obj-C)
for %%F in ("ios\Runner\AppDelegate.swift" "ios\Runner\AppDelegate.m") do (
  if exist %%~F (
    echo - Cleaning %%~F (Firebase imports/configure)
    powershell -NoProfile -Command "(Get-Content '%%~F') ^
      -notmatch '^\s*import\s+Firebase\s*$' ^
      -notmatch '^\s*@import\s+Firebase\s*;\s*$' ^
      -notmatch 'FirebaseApp\.configure\(\)' | Set-Content '%%~F'"
  ) else (
    REM Not found; that's OK
  )
)

REM Remove Firebase pods from Podfile if present
if exist "ios\Podfile" (
  echo - Cleaning ios\Podfile (Firebase pods)
  powershell -NoProfile -Command "(Get-Content 'ios/Podfile') ^
    -notmatch 'Firebase' | Set-Content 'ios/Podfile'"
) else (
  echo - ios\Podfile not found (OK)
)

REM --- Step 4: Flutter clean and re-get
echo.
echo - Running flutter clean ...
flutter clean 1>nul 2>nul
if errorlevel 1 (
  echo   [WARN] flutter clean encountered issues. Continuing...
) else (
  echo   OK
)

echo - Running flutter pub get ...
flutter pub get 1>nul 2>nul
if errorlevel 1 (
  echo   [WARN] flutter pub get encountered issues. You may run it manually.
) else (
  echo   OK
)

echo.
echo  ============================================================
echo   Firebase removal routine finished.
echo   Next: try `flutter run` to verify the app builds without Firebase.
echo  ============================================================
echo.
exit /b 0

:pubremove
REM Helper: try to remove a package, suppress error output
flutter pub remove %1 1>nul 2>nul
if errorlevel 1 (
  echo   (skip) %1 not found or could not be removed.
) else (
  echo   Removed %1
)
exit /b 0
