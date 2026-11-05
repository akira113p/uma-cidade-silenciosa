# Versionamento por sessão. Da raiz do projeto:
#   pwsh scripts/sessao.ps1 -Inicio
#   pwsh scripts/sessao.ps1 -Fim -Mensagem "o que mudou" [-Caminhos src/server/X.luau,docs/y.md]
# -Inicio: mostra branch, faz pull --ff-only, avisa de árvore suja, mostra a última tag e o place oficial.
# -Fim:    roda checar.ps1 (aborta se falhar), grava data e nº em src/shared/Config/Versao.luau, adiciona, MOSTRA A LISTA do que
#          entrou, commita (Co-Authored-By), cria a tag anotada sessao-AAAA-MM-DD-N (N = próximo livre do dia) e dá push com a tag.
# Sem -Caminhos adiciona tudo (git add -A): só use assim quando você é a única sessão. Com -Caminhos adiciona e commita SÓ esses
# caminhos (mais o Versao.luau); o que outra sessão deixou na árvore ou no índice fica de fora.
param(
    [switch]$Inicio,
    [switch]$Fim,
    [string]$Mensagem,
    [string[]]$Caminhos
)

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$coautor = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
$arquivoVersao = 'src/shared/Config/Versao.luau'

function ExecGit {
    # roda git e devolve a saída (linhas); aborta se o código de saída não for 0
    $saida = & git @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "git $($args -join ' ') falhou ($LASTEXITCODE): $($saida -join ' | ')" }
    return $saida
}

function PlaceOficial {
    $p = Get-Content default.project.json -Raw | ConvertFrom-Json
    if ($p.servePlaceIds) { return ($p.servePlaceIds -join ', ') }
    return '(servePlaceIds ausente em default.project.json)'
}

if ($Inicio -eq $Fim) {
    Write-Host 'Use -Inicio ou -Fim (um dos dois).' -ForegroundColor Red
    exit 2
}

if ($Inicio) {
    $branch = (ExecGit rev-parse --abbrev-ref HEAD) -join ''
    Write-Host "Branch: $branch" -ForegroundColor Cyan
    Write-Host "Place oficial (default.project.json > servePlaceIds): $(PlaceOficial)  | conferir game.PlaceId ao abrir o Studio"
    & git pull --ff-only 2>&1 | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) {
        Write-Host 'pull --ff-only falhou (histórico divergiu ou sem rede). Resolva antes de trabalhar; não force.' -ForegroundColor Yellow
    }
    $suja = ExecGit status --short
    if ($suja) {
        Write-Host "`nÁrvore SUJA ($(@($suja).Count) caminho(s)). Pode ser de outra sessão: não reverta o que não é seu." -ForegroundColor Yellow
        $suja | Select-Object -First 30 | ForEach-Object { Write-Host "  $_" }
        if (@($suja).Count -gt 30) { Write-Host "  ... e mais $(@($suja).Count - 30)" }
    } else {
        Write-Host 'Árvore limpa.' -ForegroundColor Green
    }
    $tag = & git describe --tags --abbrev=0 --match 'sessao-*' 2>$null
    if ($LASTEXITCODE -eq 0 -and $tag) {
        $info = (ExecGit log -1 --format='%h %ci %s' $tag) -join ''
        Write-Host "`nÚltima tag de sessão: $tag  ($info)"
        $depois = (ExecGit rev-list --count "$tag..HEAD") -join ''
        Write-Host "Commits desde a tag: $depois"
    } else {
        Write-Host "`nNenhuma tag sessao-* ainda."
    }
    exit 0
}

# -Fim ------------------------------------------------------------------------------------------------------------
if (-not $Mensagem -or $Mensagem.Trim().Length -eq 0) {
    Write-Host '-Fim exige -Mensagem "o que mudou".' -ForegroundColor Red
    exit 2
}

Write-Host '== checar.ps1 (aborta se falhar)' -ForegroundColor Cyan
& pwsh -NoProfile -File (Join-Path $PSScriptRoot 'checar.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host 'checar.ps1 falhou: sessão NÃO fechada (nada commitado, nada alterado em Versao).' -ForegroundColor Red
    exit 1
}

# Próximo nº do dia: considera tags locais e as do remoto
& git fetch --tags --quiet 2>$null
$data = Get-Date -Format 'yyyy-MM-dd'
$existentes = @(ExecGit tag -l "sessao-$data-*")
$maior = 0
foreach ($t in $existentes) {
    if ($t -match "^sessao-$data-(\d+)$") { $maior = [Math]::Max($maior, [int]$Matches[1]) }
}
$n = $maior + 1
$tag = "sessao-$data-$n"
$build = "$data.$n"

# Config/Versao.luau: mantém os comentários do topo, troca build e nota (uma linha, sem aspas problemáticas)
$nota = ($Mensagem -split "`r?`n")[0].Trim() -replace '\\', '/' -replace '"', "'"
if ($nota.Length -gt 100) { $nota = $nota.Substring(0, 97) + '...' }
$cabecalho = @(Get-Content $arquivoVersao | Where-Object { $_ -match '^\s*--' })
$conteudo = ($cabecalho -join "`n") + "`nreturn {`n`tbuild = `"$build`",`n`tnota = `"$nota`",`n}`n"
[System.IO.File]::WriteAllText((Join-Path (Get-Location) $arquivoVersao), $conteudo, (New-Object System.Text.UTF8Encoding($false)))
& stylua $arquivoVersao
if ($LASTEXITCODE -ne 0) { throw 'stylua falhou em Versao.luau' }

# Adiciona
if ($Caminhos -and $Caminhos.Count -gt 0) {
    $alvo = @($Caminhos | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) + $arquivoVersao
    ExecGit add -- @alvo | Out-Null
    $modo = "SÓ estes caminhos: $($alvo -join ', ')"
} else {
    ExecGit add -A | Out-Null
    $alvo = $null
    $modo = 'TUDO (git add -A)'
}

# Lista do que entra: o que o commit vai levar de verdade
if ($alvo) { $lista = ExecGit diff --cached --name-status -- @alvo } else { $lista = ExecGit diff --cached --name-status }
Write-Host "`n== Entra no commit ($modo): $(@($lista).Count) arquivo(s)" -ForegroundColor Cyan
@($lista) | Select-Object -First 200 | ForEach-Object { Write-Host "  $_" }
if (@($lista).Count -gt 200) { Write-Host "  ... e mais $(@($lista).Count - 200)" }
if (-not $alvo) {
    Write-Host 'Aviso: git add -A leva tudo da árvore, inclusive o que outra sessão deixou. Em sessão paralela use -Caminhos.' -ForegroundColor Yellow
}

# Commit (mensagem por arquivo, sem problema de aspas)
$msg = "$Mensagem`n`n$coautor`n"
$arqMsg = New-TemporaryFile
[System.IO.File]::WriteAllText($arqMsg.FullName, $msg, (New-Object System.Text.UTF8Encoding($false)))
try {
    if ($alvo) { ExecGit commit -F $arqMsg.FullName -- @alvo | Out-Null } else { ExecGit commit -F $arqMsg.FullName | Out-Null }
} finally {
    Remove-Item $arqMsg.FullName -ErrorAction SilentlyContinue
}
$hash = (ExecGit rev-parse --short HEAD) -join ''

ExecGit tag -a $tag -m "$Mensagem" | Out-Null

& git push origin HEAD $tag 2>&1 | ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    Write-Host "`nPush FALHOU. Commit $hash e tag $tag existem só localmente. Faça 'git pull --ff-only' (ou resolva) e 'git push origin HEAD $tag'." -ForegroundColor Red
    exit 1
}

Write-Host "`nSessão fechada: commit $hash, tag $tag, build $build." -ForegroundColor Green
