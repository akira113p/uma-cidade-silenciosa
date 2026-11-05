# As 4 checagens antes de o Studio ver qualquer coisa. Rodar da raiz do projeto: pwsh scripts/checar.ps1
$falhas = @()

function Passo([string]$nome, [scriptblock]$comando) {
    Write-Host "== $nome" -ForegroundColor Cyan
    & $comando
    if ($LASTEXITCODE -ne 0) { $script:falhas += $nome; Write-Host "FALHOU: $nome" -ForegroundColor Red }
}

Passo 'rojo build' { New-Item -ItemType Directory -Force build | Out-Null; rojo build default.project.json -o build/place.rbxl }
Passo 'testes' {
    $global:LASTEXITCODE = 0
    foreach ($t in Get-ChildItem tests -Filter *.spec.luau) {
        lune run $t.FullName
        if ($LASTEXITCODE -ne 0) { return }
    }
}
Passo 'selene' { selene src }
Passo 'stylua' { stylua --check src tests }

if ($falhas.Count -gt 0) {
    Write-Host "`n$($falhas.Count) checagem(ns) falharam: $($falhas -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "`nTudo verde." -ForegroundColor Green
