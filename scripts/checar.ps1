# As 4 checagens antes de o Studio ver qualquer coisa. Rodar da raiz do projeto: pwsh scripts/checar.ps1
$falhas = @()

function Passo([string]$nome, [scriptblock]$comando) {
    Write-Host "== $nome" -ForegroundColor Cyan
    & $comando
    if ($LASTEXITCODE -ne 0) { $script:falhas += $nome; Write-Host "FALHOU: $nome" -ForegroundColor Red }
}

Passo 'rojo build' { New-Item -ItemType Directory -Force build | Out-Null; rojo build build.project.json -o build/place.rbxl }
Passo 'projetos iguais' {
    # default.project.json (rojo serve, sem mapa) tem de ser igual a build.project.json menos o mapa.
    $b = Get-Content build.project.json -Raw | ConvertFrom-Json -Depth 30
    $d = Get-Content default.project.json -Raw | ConvertFrom-Json -Depth 30
    $b.tree.Workspace.PSObject.Properties.Remove('Mapa')
    $iguais = ($b.tree | ConvertTo-Json -Depth 30 -Compress) -ceq ($d.tree | ConvertTo-Json -Depth 30 -Compress)
    $global:LASTEXITCODE = if ($iguais) { 0 } else { 1 }
}
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
