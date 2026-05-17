@echo off
setlocal EnableExtensions
cd /d "%~dp0"
echo.
echo === LLM workspace: npm install (root/server/client) + formatters + tests ===
echo.
where node >nul 2>&1
if errorlevel 1 (
  echo [ERROR] Node.js not found. Install Node 18+ from https://nodejs.org/
  exit /b 1
)
echo [1/7] npm install (root)...
call npm install
if errorlevel 1 (
  echo [ERROR] npm install failed in repo root.
  exit /b 1
)
echo [2/7] npm install (server)...
call npm install --prefix server
if errorlevel 1 (
  echo [ERROR] npm install failed in server/.
  exit /b 1
)
echo [3/7] npm install (client)...
call npm install --prefix client
if errorlevel 1 (
  echo [ERROR] npm install failed in client/.
  exit /b 1
)
if not exist "server\.env" (
  echo.
  echo [WARN] server\.env missing. Copy server\.env.example and set GEMINI_API_KEY for chat.
  if exist "server\.env.example" (
    echo        copy server\.env.example server\.env
  )
) else (
  findstr /B /C:"GEMINI_API_KEY=" "server\.env" | findstr /V /C:"GEMINI_API_KEY=$" >nul 2>&1
  if errorlevel 1 findstr /B /C:"GEMINI_API_KEY=." "server\.env" >nul 2>&1
)
echo.
echo [4/7] Python formatter (Black) - only if Python already installed...
set "BLACK_OK=0"
where py >nul 2>&1 && (
  py -m black --version >nul 2>&1 && set "BLACK_OK=1"
)
if "%BLACK_OK%"=="0" (
  where python >nul 2>&1 && (
    python -m black --version >nul 2>&1 && set "BLACK_OK=1"
  )
)
if "%BLACK_OK%"=="1" (
  echo        Black already available.
) else (
  where py >nul 2>&1 && (
    echo        Installing Black via: py -m pip install black
    py -m pip install black
    if not errorlevel 1 py -m black --version >nul 2>&1 && set "BLACK_OK=1"
  )
)
if "%BLACK_OK%"=="0" (
  where python >nul 2>&1 && (
    echo        Installing Black via: python -m pip install black
    python -m pip install black
    if not errorlevel 1 python -m black --version >nul 2>&1 && set "BLACK_OK=1"
  )
)
if "%BLACK_OK%"=="0" (
  echo [SKIP] Black not available - install Python 3 yourself, then: py -m pip install black
) else (
  echo        Black OK.
)
echo.
echo [5/7] C# formatter (CSharpier) - only if dotnet already installed...
set "CSHARP_OK=0"
where dotnet >nul 2>&1
if errorlevel 1 (
  echo [SKIP] dotnet not on PATH - no .NET SDK install from this script.
) else (
  csharpier --version >nul 2>&1 && set "CSHARP_OK=1"
  if "%CSHARP_OK%"=="0" (
    dotnet csharpier --version >nul 2>&1 && set "CSHARP_OK=1"
  )
  if "%CSHARP_OK%"=="1" (
    echo        CSharpier already available.
  ) else (
    echo        Installing: dotnet tool install -g csharpier
    dotnet tool install -g csharpier
    if not errorlevel 1 (
      csharpier --version >nul 2>&1 && set "CSHARP_OK=1"
      if "%CSHARP_OK%"=="0" dotnet csharpier --version >nul 2>&1 && set "CSHARP_OK=1"
    )
  )
  if "%CSHARP_OK%"=="0" (
    echo [WARN] CSharpier install may need a new terminal. Try: dotnet tool install -g csharpier
  ) else (
    echo        CSharpier OK.
  )
)
echo.
echo [6/7] Server unit scripts...
pushd server
call npm run test:strip-ansi
if errorlevel 1 goto :tests_failed
call npm run test:run-error-kind
if errorlevel 1 goto :tests_failed
call npm run test:workspace-env
if errorlevel 1 goto :tests_failed
call npm run test:run-csharp
if errorlevel 1 goto :tests_failed
popd
goto :after_tests
:tests_failed
popd
echo [ERROR] One or more server tests failed.
exit /b 1
:after_tests
echo.
echo [7/7] Client build smoke test...
call npm run build --prefix client
if errorlevel 1 (
  echo [ERROR] client build failed.
  exit /b 1
)
echo.
echo === All automated steps finished ===
echo.
echo Next: set server\.env (GEMINI_API_KEY), then from repo root:  npm run dev
echo UI: http://localhost:5173
echo.
echo Not covered here (manual):
echo   - Run/Format in the browser per language
echo   - POST /chat (needs API key)
echo   - Python Run needs Python; C# Run needs dotnet (not auto-installed)
echo.
pause
endlocal
exit /b 0