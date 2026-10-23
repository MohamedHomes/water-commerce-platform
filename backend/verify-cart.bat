cd /d "%~dp0"
"C:\Program Files\nodejs\node.exe" .\node_modules\jest\bin\jest.js --runInBand --watchman=false --ci test/cart.e2e-spec.ts --json --outputFile=cart-jest-report.json > cart-jest-output.txt 2>&1
echo %ERRORLEVEL% > cart-jest-exit.txt
