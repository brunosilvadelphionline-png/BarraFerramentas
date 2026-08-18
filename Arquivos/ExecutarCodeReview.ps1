param(
    [ValidateSet('Review', 'Resolve')]
    [string]$Action = 'Review',
    [string]$RepoRoot = '',
    [string]$OutputPath = '',
    [string]$HtmlOutputPath = '',
    [string]$PlanOutputPath = '',
    [string]$InstructionsOutputPath = '',
    [string]$MetadataOutputPath = '',
    [string]$CompilerDiagnosticsOutputPath = '',
    [string]$LogOutputPath = '',
    [string]$TaskCode = '',
    [string]$Model = '',
    [string]$CompilerTargets = '',
    [string]$ReviewInputPath = '',
    [string]$SelectedFindingsPath = ''
)

$ErrorActionPreference = 'Stop'
$InstructionsHeading = 'Instru' + [char]231 + [char]245 + 'es para teste'
$InstructionsHeadingPrompt = 'Instrucoes para teste'
$InstructionsHeadingPattern = '(?:' + [regex]::Escape($InstructionsHeading) +
    '|Instrucoes para teste|Instru\?\?es para teste)'

function Convert-InlineMarkdown {
    param([string]$Text)

    $encoded = [System.Net.WebUtility]::HtmlEncode($Text)
    $encoded = [regex]::Replace($encoded, '`([^`]+)`', '<code>$1</code>')
    $encoded = [regex]::Replace($encoded, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
    return $encoded
}

function Convert-MarkdownToHtml {
    param(
        [string]$Markdown,
        [string]$Title
    )

    $body = New-Object System.Text.StringBuilder
    $inCode = $false
    $inList = $false

    foreach ($line in ($Markdown -split "`r?`n")) {
        if ($line -match '^\s*(```|~~~)') {
            if ($inCode) {
                [void]$body.AppendLine('</code></pre>')
                $inCode = $false
            } else {
                if ($inList) {
                    [void]$body.AppendLine('</ul>')
                    $inList = $false
                }

                [void]$body.AppendLine('<pre><code>')
                $inCode = $true
            }

            continue
        }

        if ($inCode) {
            [void]$body.AppendLine([System.Net.WebUtility]::HtmlEncode($line))
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            if ($inList) {
                [void]$body.AppendLine('</ul>')
                $inList = $false
            }

            continue
        }

        if ($line -match '^(#{1,4})\s+(.+)$') {
            if ($inList) {
                [void]$body.AppendLine('</ul>')
                $inList = $false
            }

            $level = [Math]::Min($matches[1].Length, 4)
            [void]$body.AppendLine("<h$level>$(Convert-InlineMarkdown $matches[2])</h$level>")
            continue
        }

        if ($line -match '^\s*[-*]\s+(.+)$') {
            if (-not $inList) {
                [void]$body.AppendLine('<ul>')
                $inList = $true
            }

            [void]$body.AppendLine("<li>$(Convert-InlineMarkdown $matches[1])</li>")
            continue
        }

        if ($inList) {
            [void]$body.AppendLine('</ul>')
            $inList = $false
        }

        [void]$body.AppendLine("<p>$(Convert-InlineMarkdown $line)</p>")
    }

    if ($inCode) {
        [void]$body.AppendLine('</code></pre>')
    }

    if ($inList) {
        [void]$body.AppendLine('</ul>')
    }

    $safeTitle = [System.Net.WebUtility]::HtmlEncode($Title)
    $generatedAt = [System.Net.WebUtility]::HtmlEncode((Get-Date).ToString('dd/MM/yyyy HH:mm'))

    return @"
<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$safeTitle</title>
  <style>
    :root {
      color-scheme: light;
      --bg: #f4f7fb;
      --panel: #ffffff;
      --text: #1f2937;
      --muted: #667085;
      --border: #d9e2ec;
      --accent: #0f766e;
      --code-bg: #111827;
      --code-text: #e5e7eb;
    }

    * { box-sizing: border-box; }

    body {
      margin: 0;
      background: var(--bg);
      color: var(--text);
      font: 15px/1.55 "Segoe UI", Arial, sans-serif;
    }

    main {
      max-width: 1120px;
      margin: 32px auto;
      padding: 0 22px;
    }

    article {
      background: var(--panel);
      border: 1px solid var(--border);
      border-radius: 8px;
      box-shadow: 0 18px 45px rgba(15, 23, 42, .08);
      padding: 30px 34px;
    }

    .meta {
      color: var(--muted);
      font-size: 13px;
      margin-bottom: 22px;
    }

    h1, h2, h3, h4 {
      color: #0f172a;
      line-height: 1.25;
      margin: 26px 0 10px;
    }

    h1 {
      border-bottom: 3px solid var(--accent);
      font-size: 28px;
      margin-top: 0;
      padding-bottom: 10px;
    }

    h2 { font-size: 22px; }
    h3 { font-size: 18px; }
    h4 { font-size: 16px; }

    p { margin: 10px 0; }
    ul { margin: 8px 0 16px 24px; padding: 0; }
    li { margin: 6px 0; }

    code {
      background: #edf2f7;
      border-radius: 4px;
      color: #9f1239;
      font-family: Consolas, "Courier New", monospace;
      font-size: 13px;
      padding: 2px 5px;
    }

    pre {
      background: var(--code-bg);
      border-radius: 8px;
      color: var(--code-text);
      overflow: auto;
      padding: 16px;
      white-space: pre;
    }

    pre code {
      background: transparent;
      color: inherit;
      padding: 0;
    }
  </style>
</head>
<body>
  <main>
    <article>
      <div class="meta">Gerado em $generatedAt</div>
$($body.ToString())
    </article>
  </main>
</body>
</html>
"@
}

function Write-ReviewHtml {
    param(
        [string]$MarkdownPath,
        [string]$HtmlPath
    )

    $htmlDir = Split-Path -Parent $HtmlPath
    if (-not [string]::IsNullOrWhiteSpace($htmlDir)) {
        New-Item -ItemType Directory -Force -Path $htmlDir | Out-Null
    }

    $markdown = Get-Content -LiteralPath $MarkdownPath -Raw -Encoding UTF8
    $title = 'Code review'
    if (-not [string]::IsNullOrWhiteSpace($TaskCode)) {
        $title = "$title - $TaskCode"
    }
    $html = Convert-MarkdownToHtml -Markdown $markdown -Title $title
    $html | Set-Content -LiteralPath $HtmlPath -Encoding UTF8
}

function Write-ReviewFile {
    param([string]$Text)

    $outputDir = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
        New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    }

    $Text | Set-Content -LiteralPath $OutputPath -Encoding UTF8
    Write-ReviewHtml -MarkdownPath $OutputPath -HtmlPath $HtmlOutputPath
}

function Normalize-InstructionsHeading {
    param([string]$MarkdownPath)

    $markdown = Get-Content -LiteralPath $MarkdownPath -Raw -Encoding UTF8
    $normalized = [regex]::Replace(
        $markdown,
        "(?m)^##[ \t]+$InstructionsHeadingPattern[ \t]*(?=\r?$)",
        "## $InstructionsHeading"
    )
    $normalized | Set-Content -LiteralPath $MarkdownPath -Encoding UTF8
}

function Write-PlanFile {
    param([string]$MarkdownPath)

    $markdown = Get-Content -LiteralPath $MarkdownPath -Raw -Encoding UTF8
    $match = [regex]::Match(
        $markdown,
        '(?ms)^##\s+Plano de testes para QA\s*\r?\n(?<plan>.*?)(?=^##\s+|\z)'
    )
    if (-not $match.Success -or [string]::IsNullOrWhiteSpace($match.Groups['plan'].Value)) {
        throw 'O Codex nao retornou a secao obrigatoria "Plano de testes para QA".'
    }

    $planDir = Split-Path -Parent $PlanOutputPath
    if (-not [string]::IsNullOrWhiteSpace($planDir)) {
        New-Item -ItemType Directory -Force -Path $planDir | Out-Null
    }
    $match.Groups['plan'].Value.Trim() | Set-Content -LiteralPath $PlanOutputPath -Encoding UTF8
}

function Write-InstructionsFile {
    param([string]$MarkdownPath)

    $markdown = Get-Content -LiteralPath $MarkdownPath -Raw -Encoding UTF8
    $match = [regex]::Match(
        $markdown,
        "(?ms)^##\s+$([regex]::Escape($InstructionsHeading))\s*\r?\n(?<instructions>.*?)(?=^##\s+|\z)"
    )
    if (-not $match.Success -or [string]::IsNullOrWhiteSpace($match.Groups['instructions'].Value)) {
        throw "O Codex nao retornou a secao obrigatoria `"$InstructionsHeading`"."
    }

    $instructionsDir = Split-Path -Parent $InstructionsOutputPath
    if (-not [string]::IsNullOrWhiteSpace($instructionsDir)) {
        New-Item -ItemType Directory -Force -Path $instructionsDir | Out-Null
    }
    $instructions = $match.Groups['instructions'].Value.Trim()
    if ($instructions -eq 'Nenhuma instrucao adicional.') {
        $instructions = ''
    }
    $instructions | Set-Content -LiteralPath $InstructionsOutputPath -Encoding UTF8
}

function Assert-FindingContract {
    param([string]$MarkdownPath)

    $markdown = Get-Content -LiteralPath $MarkdownPath -Raw -Encoding UTF8
    $section = [regex]::Match(
        $markdown,
        '(?ms)^##\s+Achados tecnicos\s*\r?\n(?<findings>.*?)(?=^##\s+|\z)'
    )
    if (-not $section.Success) {
        throw 'O Codex nao retornou a secao obrigatoria "Achados tecnicos".'
    }

    $content = $section.Groups['findings'].Value.Trim()
    $headings = [regex]::Matches($content, '(?m)^###\s+(?<label>.+?)\s*$')
    if ($headings.Count -eq 0) {
        if ($content -ne 'Nenhum problema tecnico encontrado.') {
            throw 'O Codex retornou achados sem os rotulos obrigatorios ACHADO-NNN.'
        }
        return
    }

    $seen = @{}
    $findingBlocks = [regex]::Matches(
        $content,
        '(?ms)^###\s+(?<label>.+?)\s*\r?\n(?<body>.*?)(?=^###\s+|\z)'
    )
    foreach ($heading in $headings) {
        $label = $heading.Groups['label'].Value.Trim()
        if ($label -notmatch '^ACHADO-\d{3} \| [^|]+ \| .+$') {
            throw "Rotulo de achado invalido: $label"
        }
        if ($seen.ContainsKey($label)) {
            throw "Rotulo de achado duplicado: $label"
        }
        $seen[$label] = $true
    }

    foreach ($finding in $findingBlocks) {
        $findingLabel = $finding.Groups['label'].Value.Trim()
        $optionHeadings = [regex]::Matches(
            $finding.Groups['body'].Value,
            '(?m)^####\s+(?<label>.+?)\s*$'
        )
        if ($optionHeadings.Count -eq 1) {
            throw "O achado '$findingLabel' possui somente uma opcao. Use 'Correcao recomendada' quando nao houver alternativas."
        }
        if ($optionHeadings.Count -gt 1) {
            $optionSeen = @{}
            $recommendedCount = 0
            foreach ($optionHeading in $optionHeadings) {
                $optionLabel = $optionHeading.Groups['label'].Value.Trim()
                if ($optionLabel -notmatch '^OPCAO-(?<code>[A-Z]) \| (RECOMENDADA|ALTERNATIVA) \| .+$') {
                    throw "Rotulo de opcao invalido no achado '$findingLabel': $optionLabel"
                }
                $optionCode = $matches['code']
                if ($optionSeen.ContainsKey($optionCode)) {
                    throw "Codigo de opcao duplicado no achado '$findingLabel': OPCAO-$optionCode"
                }
                if ($optionLabel -match '^OPCAO-[A-Z] \| RECOMENDADA \|') {
                    $recommendedCount++
                }
                $optionSeen[$optionCode] = $true
            }
            if ($recommendedCount -ne 1) {
                throw "O achado '$findingLabel' deve possuir exatamente uma opcao marcada como RECOMENDADA."
            }
        }
    }
}

function Get-DelphiCompilerDiagnostics {
    param(
        [string]$RepositoryRoot,
        [string[]]$ChangedFiles,
        [string[]]$SelectedTargets
    )

    $delphiExtensions = @('.pas', '.dfm', '.dpr', '.inc')
    $delphiFiles = @(
        $ChangedFiles | Where-Object {
            $delphiExtensions -contains [System.IO.Path]::GetExtension($_).ToLowerInvariant()
        }
    )
    if ($delphiFiles.Count -eq 0) {
        return [pscustomobject]@{
            Diagnostics = @()
            Failures = @()
            Summary = 'Nenhum arquivo Delphi alterado no escopo do code review.'
        }
    }

    $dcc32 = 'C:\Program Files (x86)\Borland\Delphi7\Bin\DCC32.EXE'
    if (-not (Test-Path -LiteralPath $dcc32)) {
        $message = "Compilador Delphi nao encontrado para verificar hints e warnings: $dcc32"
        return [pscustomobject]@{
            Diagnostics = @()
            Failures = @($message)
            Summary = $message
        }
    }

    $diagnosticFileNames = @{}
    $projects = @{}

    function Add-DiagnosticFileName {
        param([string]$FileName)

        if (-not [string]::IsNullOrWhiteSpace($FileName)) {
            $diagnosticFileNames[$FileName.ToLowerInvariant()] = $FileName
        }
    }

    function Add-DelphiProject {
        param([string]$RelativePath)

        $normalized = $RelativePath.Replace('/', '\')
        $fullPath = Join-Path $RepositoryRoot $normalized
        if (-not (Test-Path -LiteralPath $fullPath)) {
            throw "Projeto Delphi necessario para a verificacao nao encontrado: $fullPath"
        }
        $projects[$normalized.ToLowerInvariant()] = $normalized
    }

    $projectByTarget = @{
        'sga' = 'SgaDelphi\Sga.dpr'
        'sgarh' = 'SgaRh\SgaRh.dpr'
        'sgawscgi' = 'SgaWS\SgaWsCGI.dpr'
    }
    foreach ($selectedTarget in $SelectedTargets) {
        if ([string]::IsNullOrWhiteSpace($selectedTarget)) {
            continue
        }

        $targetKey = $selectedTarget.Trim().ToLowerInvariant()
        if (-not $projectByTarget.ContainsKey($targetKey)) {
            throw "Executavel desconhecido para a compilacao diagnostica: $selectedTarget"
        }
        Add-DelphiProject $projectByTarget[$targetKey]
    }
    if ($projects.Count -eq 0) {
        return [pscustomobject]@{
            Diagnostics = @()
            Failures = @()
            Summary = 'Nenhum executavel Delphi selecionado para a compilacao diagnostica.'
        }
    }

    foreach ($changedFile in $delphiFiles) {
        $fileName = [System.IO.Path]::GetFileName($changedFile)
        Add-DiagnosticFileName $fileName
    }

    $repositoryParent = Split-Path -Parent $RepositoryRoot
    $componentsRoot = Join-Path $repositoryParent 'Componentes'
    if (-not (Test-Path -LiteralPath $componentsRoot)) {
        $componentsRoot = 'C:\Desenvolvimento\Componentes'
    }

    $unitPaths = @(
        'C:\Program Files (x86)\Borland\Delphi7\Lib',
        'C:\Program Files (x86)\Borland\Delphi7\Imports',
        (Join-Path $componentsRoot 'FastMM4'),
        (Join-Path $RepositoryRoot 'Delphi'),
        (Join-Path $RepositoryRoot 'SgaDelphi'),
        (Join-Path $RepositoryRoot 'Sga'),
        'C:\Program Files (x86)\Devart\UniDAC for Delphi 7\Lib',
        (Join-Path $RepositoryRoot 'SgaDll'),
        (Join-Path $RepositoryRoot 'SgaCont'),
        (Join-Path $RepositoryRoot 'SgaExp'),
        (Join-Path $RepositoryRoot 'SgaPro'),
        (Join-Path $RepositoryRoot 'SgaAlm'),
        (Join-Path $RepositoryRoot 'SgaRec'),
        (Join-Path $RepositoryRoot 'SgaRh'),
        (Join-Path $RepositoryRoot 'SgaLab'),
        (Join-Path $RepositoryRoot 'SgaWS'),
        (Join-Path $RepositoryRoot 'SgaGuardian'),
        (Join-Path $RepositoryRoot 'Delphi\ZLib'),
        (Join-Path $RepositoryRoot 'SgaAgenda'),
        (Join-Path $componentsRoot 'indy10'),
        (Join-Path $componentsRoot 'Gnostice\eDocEngine VCL\Lib\D7'),
        (Join-Path $componentsRoot 'Gnostice\Shared3\Lib\D7'),
        (Join-Path $componentsRoot 'TNTComponentsSource\Source'),
        (Join-Path $componentsRoot 'TMS\TMS Smooth Controls'),
        (Join-Path $componentsRoot 'TMS\TMS Smooth Controls\Delphi7'),
        (Join-Path $componentsRoot 'HtmlViewer\source'),
        (Join-Path $componentsRoot 'CEF4Delphi'),
        (Join-Path $componentsRoot 'CEF4Delphi\source'),
        'C:\Program Files\TecnoSpeed\NFSe\Fontes',
        'C:\Program Files\TecnoSpeed\NFSe Nacional\Fontes',
        'C:\Program Files (x86)\madCollection\madBasic\Delphi 7',
        'C:\Program Files (x86)\madCollection\madDisAsm\Delphi 7',
        'C:\Program Files (x86)\madCollection\madExcept\Delphi 7',
        'C:\Program Files (x86)\madCollection\Plugins\win32',
        'C:\Program Files (x86)\madCollection\madKernel\Delphi 7',
        'C:\Program Files (x86)\madCollection\madSecurity\Delphi 7',
        'C:\Program Files (x86)\madCollection\madShell\Delphi 7'
    ) | Where-Object { Test-Path -LiteralPath $_ } | Sort-Object -Unique

    $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
        'gerador-review-compile-' + [guid]::NewGuid().ToString('N')
    )
    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

    $relevantDiagnostics = New-Object System.Collections.Generic.List[string]
    $compilerFailures = New-Object System.Collections.Generic.List[string]
    try {
        foreach ($projectRelativePath in ($projects.Values | Sort-Object)) {
            $projectPath = Join-Path $RepositoryRoot $projectRelativePath
            $projectName = [System.IO.Path]::GetFileNameWithoutExtension($projectPath)
            $projectOutput = Join-Path $tempRoot $projectName
            $dcuOutput = Join-Path $projectOutput 'DCU'
            New-Item -ItemType Directory -Path $dcuOutput -Force | Out-Null

            $compilerArguments = @(
                '-B',
                $projectPath,
                '-Q',
                '-W+',
                '-H+',
                '-$J+',
                ('-E' + $projectOutput),
                ('-N' + $dcuOutput)
            )
            foreach ($unitPath in $unitPaths) {
                $compilerArguments += '-u' + $unitPath
            }

            $previousErrorActionPreference = $ErrorActionPreference
            Push-Location (Split-Path -Parent $projectPath)
            try {
                # O DCC32 pode escrever diagnosticos em stderr. Eles precisam
                # ser capturados mesmo com ErrorActionPreference=Stop no script.
                $ErrorActionPreference = 'Continue'
                $compilerOutput = @(& $dcc32 @compilerArguments 2>&1 | ForEach-Object {
                    $_.ToString()
                })
                $compilerExitCode = $LASTEXITCODE
            } finally {
                $ErrorActionPreference = $previousErrorActionPreference
                Pop-Location
            }

            foreach ($line in $compilerOutput) {
                if ($line -notmatch '(?i)\b(?:hint|warning)\b') {
                    continue
                }

                foreach ($diagnosticFileName in $diagnosticFileNames.Values) {
                    $filePattern = '(?i)(?<![A-Z0-9_.-])' +
                        [regex]::Escape($diagnosticFileName) +
                        '(?=\(|:|\s|$)'
                    if ([regex]::IsMatch($line, $filePattern)) {
                        $entry = "[$projectRelativePath] $line"
                        if (-not $relevantDiagnostics.Contains($entry)) {
                            [void]$relevantDiagnostics.Add($entry)
                        }
                        break
                    }
                }
            }

            if ($compilerExitCode -ne 0) {
                $failure = "A compilacao diagnostica de '$projectRelativePath' nao foi concluida (codigo $compilerExitCode)."
                $failureDetails = @($compilerOutput | Where-Object {
                    $_ -match '(?i)\b(?:error|fatal)\b'
                } | Select-Object -Last 5)
                if ($failureDetails.Count -gt 0) {
                    $failure = $failure + ' ' + ($failureDetails -join ' | ')
                }
                [void]$compilerFailures.Add($failure)
            }
        }
    } finally {
        if (Test-Path -LiteralPath $tempRoot) {
            Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    if ($relevantDiagnostics.Count -eq 0) {
        $summary = 'Nenhum hint ou warning do compilador Delphi foi encontrado nos arquivos alterados.'
    } else {
        $summary = $relevantDiagnostics -join "`r`n"
    }
    if ($compilerFailures.Count -gt 0) {
        $summary = $summary + "`r`n`r`nAvisos da compilacao diagnostica:`r`n" +
            ($compilerFailures -join "`r`n")
    }

    return [pscustomobject]@{
        Diagnostics = @($relevantDiagnostics.ToArray())
        Failures = @($compilerFailures.ToArray())
        Summary = $summary
    }
}

function Write-MetadataFile {
    param(
        [string]$Branch,
        [string]$BaseRef,
        [string[]]$Files,
        [string]$CompilerStatus = 'nao_aplicavel',
        [string]$CompilerMessage = '',
        [int]$CompilerDiagnosticCount = 0
    )

    $metadataDir = Split-Path -Parent $MetadataOutputPath
    if (-not [string]::IsNullOrWhiteSpace($metadataDir)) {
        New-Item -ItemType Directory -Force -Path $metadataDir | Out-Null
    }

    $singleLineCompilerMessage = $CompilerMessage -replace '[\r\n]+', ' | '
    @(
        '[Review]'
        "RepoRoot=$RepoRoot"
        "Branch=$Branch"
        "BaseRef=$BaseRef"
        "TaskCode=$TaskCode"
        "ChangedFileCount=$($Files.Count)"
        "AnalyzedAt=$((Get-Date).ToString('yyyy-MM-ddTHH:mm:ss.fff'))"
        ''
        '[Compiler]'
        "Status=$CompilerStatus"
        "Message=$singleLineCompilerMessage"
        "DiagnosticCount=$CompilerDiagnosticCount"
    ) | Set-Content -LiteralPath $MetadataOutputPath -Encoding ASCII
}

function Get-TrackedDiffFingerprint {
    $diffLines = @(
        & git -C $RepoRoot diff --no-ext-diff --binary HEAD --
    )
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel obter o diff rastreado do repositorio.'
    }

    $diffText = $diffLines -join "`n"
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $diffBytes = [System.Text.Encoding]::UTF8.GetBytes($diffText)
        return ([System.BitConverter]::ToString(
            $sha256.ComputeHash($diffBytes)
        ) -replace '-', '')
    } finally {
        $sha256.Dispose()
    }
}

function Invoke-CodexRun {
    param(
        [string]$Prompt,
        [ValidateSet('read-only', 'workspace-write')]
        [string]$Sandbox
    )

    $tmpPrompt = Join-Path $env:TEMP ("codex-prompt-" + [guid]::NewGuid().ToString() + ".md")
    $Prompt | Set-Content -LiteralPath $tmpPrompt -Encoding UTF8
    $previousErrorActionPreference = $ErrorActionPreference
    try {
        # A CLI escreve progresso e falhas em stderr. Em Windows PowerShell,
        # ErrorActionPreference=Stop interromperia o script antes de salvar o log.
        $ErrorActionPreference = 'Continue'
        $codexMessages = @(
            Get-Content -LiteralPath $tmpPrompt -Raw |
                & codex exec --cd $RepoRoot --model $Model --sandbox $Sandbox -c 'approval_policy="never"' --color never --ephemeral -o $OutputPath - 2>&1
        )
        $codexExitCode = $LASTEXITCODE
        $codexLog = ($codexMessages | ForEach-Object { $_.ToString() }) -join "`r`n"
        $logDir = Split-Path -Parent $LogOutputPath
        if (-not [string]::IsNullOrWhiteSpace($logDir)) {
            New-Item -ItemType Directory -Force -Path $logDir | Out-Null
        }
        $codexLog | Set-Content -LiteralPath $LogOutputPath -Encoding UTF8
        return [pscustomobject]@{
            ExitCode = $codexExitCode
            Log = $codexLog
        }
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
        Remove-Item -LiteralPath $tmpPrompt -Force -ErrorAction SilentlyContinue
    }
}

function Assert-CodexRun {
    param($Run)

    if ($Run.ExitCode -eq 0) {
        return
    }

    $details = ($Run.Log -split "`r?`n" | Select-Object -Last 40) -join "`r`n"
    if ([string]::IsNullOrWhiteSpace($details)) {
        $details = 'A CLI do Codex nao retornou detalhes adicionais.'
    }
    throw "codex exec falhou com codigo $($Run.ExitCode).`r`n`r`nDetalhes:`r`n$details`r`n`r`nLog: $LogOutputPath"
}

try {
    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        throw 'O diretorio do projeto para o code review nao foi informado.'
    }

    if ([string]::IsNullOrWhiteSpace($Model)) {
        throw 'O modelo do Codex para o code review nao foi informado.'
    }

    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $RepoRoot 'code-review.md'
    }

    if ([string]::IsNullOrWhiteSpace($HtmlOutputPath)) {
        $HtmlOutputPath = [System.IO.Path]::ChangeExtension($OutputPath, '.html')
    }

    if ([string]::IsNullOrWhiteSpace($PlanOutputPath)) {
        $PlanOutputPath = Join-Path (Split-Path -Parent $OutputPath) 'plano-testes.md'
    }

    if ([string]::IsNullOrWhiteSpace($InstructionsOutputPath)) {
        $InstructionsOutputPath = Join-Path (Split-Path -Parent $OutputPath) 'instrucoes-testes.md'
    }

    if ([string]::IsNullOrWhiteSpace($MetadataOutputPath)) {
        $MetadataOutputPath = Join-Path (Split-Path -Parent $OutputPath) 'code-review.ini'
    }

    if ([string]::IsNullOrWhiteSpace($CompilerDiagnosticsOutputPath)) {
        $CompilerDiagnosticsOutputPath = Join-Path `
            (Split-Path -Parent $OutputPath) 'compiler-diagnostics.txt'
    }
    $compilerDiagnosticsDir = Split-Path -Parent $CompilerDiagnosticsOutputPath
    if (-not [string]::IsNullOrWhiteSpace($compilerDiagnosticsDir)) {
        New-Item -ItemType Directory -Force -Path $compilerDiagnosticsDir | Out-Null
    }

    if ([string]::IsNullOrWhiteSpace($LogOutputPath)) {
        $LogOutputPath = [System.IO.Path]::ChangeExtension($OutputPath, '.log')
    }

    if (-not (Test-Path -LiteralPath $RepoRoot)) {
        throw "Repositorio nao encontrado: $RepoRoot"
    }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw 'Comando git nao encontrado no PATH.'
    }

    if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
        throw 'Comando codex nao encontrado no PATH.'
    }

    $resolvedRepoRoot = (& git -C $RepoRoot rev-parse --show-toplevel 2> $null | Select-Object -First 1)
    if ([string]::IsNullOrWhiteSpace($resolvedRepoRoot)) {
        throw "Nao foi possivel localizar a raiz Git a partir de: $RepoRoot"
    }
    $RepoRoot = $resolvedRepoRoot.Trim()

    if ($Action -eq 'Resolve') {
        if ([string]::IsNullOrWhiteSpace($ReviewInputPath) -or
            -not (Test-Path -LiteralPath $ReviewInputPath)) {
            throw "Arquivo do code review original nao encontrado: $ReviewInputPath"
        }
        if ([string]::IsNullOrWhiteSpace($SelectedFindingsPath) -or
            -not (Test-Path -LiteralPath $SelectedFindingsPath)) {
            throw "Arquivo de achados selecionados nao encontrado: $SelectedFindingsPath"
        }

        $originalReview = Get-Content -LiteralPath $ReviewInputPath -Raw -Encoding UTF8
        $selectedFindings = @(
            Get-Content -LiteralPath $SelectedFindingsPath -Encoding UTF8 |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        if ($selectedFindings.Count -eq 0) {
            throw 'Nenhum item foi selecionado para resolucao.'
        }

        $resolvePrompt = @"
Resolva exclusivamente os achados tecnicos e diagnosticos do compilador selecionados abaixo no repositorio atual.

Regras obrigatorias:
- Esta execucao especifica foi iniciada pelo usuario pelo resolvedor automatico do Gerador de executavel para teste.
- A selecao explicita dos achados, opcoes e diagnosticos pelo usuario representa a entrevista, o alinhamento e a autorizacao para implementar somente esses itens.
- Somente nesta execucao, nao interrompa o trabalho para entrevistar o usuario novamente e nao devolva perguntas antes de editar.
- Altere os arquivos localmente para corrigir somente os achados selecionados.
- Para achado sem alternativas, aplique a correcao recomendada descrita no code review original.
- Quando um achado possuir a linha OPCAO ESCOLHIDA, implemente exatamente essa opcao e nao aplique as demais alternativas do mesmo achado.
- Cada linha OPCAO ESCOLHIDA pertence ao rotulo ACHADO imediatamente anterior e representa uma diretriz, nao um achado separado.
- Se um achado com alternativas nao possuir uma OPCAO ESCOLHIDA valida, nao o altere e registre a pendencia.
- Cada linha iniciada por COMPILADOR- representa um hint ou warning real selecionado individualmente pelo desenvolvedor e deve ser corrigido.
- Nao crie commit, nao envie alteracoes e nao altere achados que nao foram selecionados.
- Preserve o comportamento existente fora do escopo das correcoes.
- Execute validacoes proporcionais ao risco quando estiverem disponiveis.
- Se algum item nao puder ser corrigido com seguranca, registre-o em Pendencias e nao improvise.
- Responda em portugues.

Formato obrigatorio do resumo final:
# Resolucao com Codex - $TaskCode
## Achados resolvidos
Para cada linha iniciada por ACHADO- ou COMPILADOR-, use como titulo de nivel 3 exatamente o mesmo rotulo selecionado.
Nao crie titulo para linhas OPCAO ESCOLHIDA.
## Alteracoes realizadas
## Validacoes executadas
## Pendencias

Tarefa: $TaskCode
Repositorio: $RepoRoot

Achados, opcoes e diagnosticos selecionados pelo desenvolvedor:
$($selectedFindings -join "`n")

Code review original:
~~~markdown
$originalReview
~~~
"@

        $trackedDiffBefore = Get-TrackedDiffFingerprint
        $resolveRun = Invoke-CodexRun -Prompt $resolvePrompt -Sandbox 'workspace-write'
        Assert-CodexRun -Run $resolveRun
        $trackedDiffAfter = Get-TrackedDiffFingerprint
        if ($trackedDiffAfter -eq $trackedDiffBefore) {
            throw 'O Codex encerrou sem produzir alteracoes rastreadas no repositorio. Consulte o resumo e o log da resolucao para verificar as pendencias.'
        }
        if (-not (Test-Path -LiteralPath $OutputPath)) {
            throw "Resumo da resolucao nao foi gerado: $OutputPath"
        }
        if ([string]::IsNullOrWhiteSpace((Get-Content -LiteralPath $OutputPath -Raw -Encoding UTF8))) {
            throw 'O Codex retornou um resumo de resolucao vazio.'
        }
        exit 0
    }

    $pathspec = @(
        ':(icase)*.pas', ':(icase)*.dfm', ':(icase)*.dpr', ':(icase)*.inc',
        ':(icase)*.sql', ':(icase)*.cs', ':(icase)*.js', ':(icase)*.py',
        ':(icase)*.json', ':(icase)*.ini', ':(icase)*.txt'
    )
    $branch = (& git -C $RepoRoot branch --show-current).Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw 'Nao foi possivel identificar a branch Git atual.'
    }
    $baseBranch = 'master'
    & git -C $RepoRoot rev-parse --verify --quiet "$baseBranch^{commit}" | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "A referencia Git obrigatoria '$baseBranch' nao foi encontrada no repositorio."
    }

    $mergeBaseOutput = @(& git -C $RepoRoot merge-base $baseBranch HEAD)
    $mergeBaseExitCode = $LASTEXITCODE
    $mergeBase = ($mergeBaseOutput | Select-Object -First 1)
    if (($mergeBaseExitCode -ne 0) -or [string]::IsNullOrWhiteSpace($mergeBase)) {
        throw "Nao foi possivel calcular o ponto de divergencia entre HEAD e '$baseBranch'."
    }
    $mergeBase = $mergeBase.Trim()
    $baseRef = "$baseBranch ($mergeBase)"

    $committed = @(& git -C $RepoRoot diff --name-only "$mergeBase..HEAD" -- $pathspec)
    if ($LASTEXITCODE -ne 0) {
        throw "Nao foi possivel listar as alteracoes commitadas da branch '$branch'."
    }
    $staged = @(& git -C $RepoRoot diff --cached --name-only -- $pathspec)
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel listar as alteracoes no staging do Git.'
    }
    $workingTree = @(& git -C $RepoRoot diff --name-only -- $pathspec)
    if ($LASTEXITCODE -ne 0) {
        throw 'Nao foi possivel listar as alteracoes versionadas no working tree do Git.'
    }
    $files = @($committed + $staged + $workingTree) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique

    if (-not $files -or ($files.Count -eq 0)) {
        Write-ReviewFile @"
# Code review - $TaskCode

## Resumo executivo
Nenhuma alteracao de codigo foi encontrada nos commits da branch apos master, no staging ou no working tree do Git.

## Achados tecnicos
Nenhum problema tecnico encontrado.

## Hints e warnings do compilador
Nenhum arquivo Delphi alterado no escopo do code review.

## Areas impactadas
- Nao foi possivel identificar areas impactadas sem alteracoes de codigo.

## Comportamento daqui para frente
- O code review considerara commits da branch posteriores a master e alteracoes versionadas locais.
- Arquivos nao versionados continuarao fora da analise.

## Exemplos antes/depois
- Antes: a branch nao possui commit proprio nem alteracao versionada local.
- Depois: sem alteracao elegivel para analisar.

## $InstructionsHeading
Nenhuma instrucao adicional.

## Plano de testes para QA
- Confirmar a abertura do executavel e validar o fluxo principal informado na tarefa.
- Conferir se a versao disponibilizada corresponde a tarefa solicitada.
"@
        Write-InstructionsFile -MarkdownPath $OutputPath
        Write-PlanFile -MarkdownPath $OutputPath
        Set-Content -LiteralPath $CompilerDiagnosticsOutputPath `
            -Value @() -Encoding UTF8
        Write-MetadataFile -Branch $branch -BaseRef $baseRef -Files @() `
            -CompilerStatus 'nao_aplicavel'
        exit 0
    }

    $selectedCompilerTargets = @(
        $CompilerTargets -split ';' | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_)
        }
    )
    try {
        $compilerResult = Get-DelphiCompilerDiagnostics `
            -RepositoryRoot $RepoRoot `
            -ChangedFiles $files `
            -SelectedTargets $selectedCompilerTargets
    } catch {
        $compilerResult = [pscustomobject]@{
            Diagnostics = @()
            Failures = @($_.Exception.Message)
            Summary = 'A compilacao diagnostica nao foi concluida: ' + $_.Exception.Message
        }
    }
    Set-Content -LiteralPath $CompilerDiagnosticsOutputPath `
        -Value @($compilerResult.Diagnostics) -Encoding UTF8
    $compilerDiagnostics = $compilerResult.Summary
    if ($compilerResult.Failures.Count -gt 0) {
        $compilerStatus = 'erro'
        $compilerMessage = $compilerResult.Failures -join ' | '
    } else {
        $compilerStatus = 'sucesso'
        $compilerMessage = ''
    }

    $prompt = @"
Faca um code review objetivo em Markdown das alteracoes versionadas existentes no repositorio atual.

Escopo obrigatorio:
- Descobrir o escopo executando Git no proprio repositorio, que ja esta definido como diretorio de trabalho.
- Calcular o ponto de divergencia com `git merge-base master HEAD` e analisar os commits da branch com `git diff --no-ext-diff <merge-base>..HEAD`.
- Considerar somente as alteracoes que estao do lado da branch atual depois da divergencia; nao incluir commits exclusivos de master.
- Analisar alteracoes staged com `git diff --cached --no-ext-diff`.
- Analisar alteracoes versionadas fora do staging com `git diff --no-ext-diff`.
- Considerar somente arquivos com extensao .pas, .dfm, .dpr, .inc, .sql, .cs, .js, .py, .json, .ini ou .txt.
- Ignorar arquivos nao versionados/nao rastreados, identificados como `??` no `git status --short` ou como `Not Versioned Files` no TortoiseGit.
- Consultar os diffs por arquivo quando isso ajudar a controlar o volume da analise.
- Outros arquivos versionados podem ser consultados apenas como contexto, mas nao devem gerar achados fora do escopo alterado.
- Priorizar bugs, regressoes, problemas Delphi/VCL, vazamento de recurso, SQL inseguro, erros em eventos/forms .dfm, compatibilidade e falta de teste.
- Apresentar os diagnosticos reais do compilador Delphi fornecidos ao final deste prompt somente na secao Hints e warnings do compilador.
- Nao transformar hints ou warnings do compilador em ACHADO-NNN; eles possuem selecao e resolucao independentes no gerador.
- Preservar nessa secao todos os diagnosticos e avisos de falha da compilacao fornecidos, sem omitir itens.
- Nao alterar arquivos.
- Retornar achados com severidade, arquivo e motivo. Se nao houver problemas, dizer isso claramente.
- Para cada problema real, criar um titulo de nivel 3 no formato exato: `### ACHADO-NNN | SEVERIDADE | Rotulo curto e unico`.
- Numerar os rotulos sequencialmente a partir de ACHADO-001 e nao reutilizar rotulos.
- O titulo de nivel 3 sera usado literalmente no HTML e na selecao do desenvolvedor; nao usar Markdown adicional dentro do rotulo.
- Abaixo de cada rotulo, informar arquivo/local, problema e impacto.
- Quando existir uma unica forma segura de corrigir, informar `Correcao recomendada:` e descrever somente essa correcao, sem criar subtitulos de opcao.
- Quando existirem duas ou mais formas viaveis e mutuamente exclusivas de corrigir, nao decidir pelo desenvolvedor e nao juntar alternativas com "ou" em uma unica recomendacao.
- Nesse caso, criar um subtitulo de nivel 4 para cada alternativa no formato exato `#### OPCAO-A | RECOMENDADA | Rotulo curto e unico` ou `#### OPCAO-B | ALTERNATIVA | Rotulo curto e unico`, seguindo a ordem alfabetica.
- Em cada opcao, explicar objetivamente o que sera alterado, o comportamento resultante e o principal impacto ou risco da escolha.
- Todo achado com alternativas deve possuir pelo menos duas opcoes e exatamente uma delas deve ser marcada como RECOMENDADA.
- Se nao houver problema tecnico, escrever apenas `Nenhum problema tecnico encontrado.` na secao de achados e nao criar titulo de nivel 3.
- Mapear areas e rotinas de negocio impactadas e explicar o que muda daqui para frente.
- Trazer exemplos concretos de antes/depois.
- Antes do plano, criar uma secao separada somente para novidades que o tester precisa localizar ou habilitar antes de executar o teste.
- Na secao de instrucoes, incluir exclusivamente elementos novos criados pela tarefa, como campos, flags, parametros, opcoes de configuracao, botoes, menus ou telas que nao existiam antes.
- Para cada item novo, informar o caminho funcional completo, incluindo menu, tela, aba e nome exibido, alem do valor ou acao necessario para habilitar o teste quando aplicavel.
- Nao incluir elementos preexistentes, ainda que sejam usados no teste, nem explicacoes gerais sobre o cenario ou comportamento.
- Nao incluir preparacao de empresa, filial, periodo, massa de dados ou ambiente; passos de execucao; telas preexistentes usadas no fluxo; validacoes; resultados esperados ou ferramentas de conferencia. Colocar todo esse conteudo exclusivamente no plano de testes.
- Se a tarefa nao criar nenhum campo, flag, parametro, opcao de configuracao, botao, menu ou tela, escrever somente `Nenhuma instrucao adicional.` nesta secao.
- Nao incluir achados tecnicos, pendencias de correcao ou orientacoes para adiar o teste ou a homologacao. As instrucoes e o plano devem considerar o estado final esperado da tarefa, com os achados resolvidos.
- Criar um plano de testes curto, separado, voltado ao QA/operacional, sem citar codigo, classes, metodos ou detalhes de implementacao.
- Concentrar no plano todos os pre-requisitos, preparacao do cenario e da massa de dados, passos de execucao, validacoes, resultados esperados e ferramentas de conferencia.
- Responder em portugues.

Formato obrigatorio, mantendo exatamente estes titulos de nivel 2:
# Code review - $TaskCode
## Resumo executivo
## Achados tecnicos
## Hints e warnings do compilador
## Areas impactadas
## Comportamento daqui para frente
## Exemplos antes/depois
## $InstructionsHeadingPrompt
## Plano de testes para QA

Os dois ultimos topicos devem ser, nesta ordem, $InstructionsHeadingPrompt e Plano de testes para QA.
O ultimo topico deve continuar contendo apenas passos operacionais curtos e objetivos, incluindo toda a preparacao e validacao necessarias.

Tarefa: $TaskCode

Diagnosticos reais do compilador Delphi, previamente filtrados para os arquivos alterados no escopo Git:
~~~text
$compilerDiagnostics
~~~
"@

    $reviewRun = Invoke-CodexRun -Prompt $prompt -Sandbox 'read-only'
    Assert-CodexRun -Run $reviewRun

    if (-not (Test-Path -LiteralPath $OutputPath)) {
        throw "Arquivo de saida nao foi gerado: $OutputPath"
    }

    Normalize-InstructionsHeading -MarkdownPath $OutputPath
    Assert-FindingContract -MarkdownPath $OutputPath
    Write-ReviewHtml -MarkdownPath $OutputPath -HtmlPath $HtmlOutputPath
    Write-InstructionsFile -MarkdownPath $OutputPath
    Write-PlanFile -MarkdownPath $OutputPath
    Write-MetadataFile -Branch $branch -BaseRef $baseRef -Files $files `
        -CompilerStatus $compilerStatus `
        -CompilerMessage $compilerMessage `
        -CompilerDiagnosticCount $compilerResult.Diagnostics.Count

    if (-not (Test-Path -LiteralPath $HtmlOutputPath)) {
        throw "Arquivo HTML nao foi gerado: $HtmlOutputPath"
    }

    if (-not (Test-Path -LiteralPath $PlanOutputPath)) {
        throw "Plano de testes nao foi gerado: $PlanOutputPath"
    }

    if (-not (Test-Path -LiteralPath $InstructionsOutputPath)) {
        throw "Instrucoes de teste nao foram geradas: $InstructionsOutputPath"
    }

    if (-not (Test-Path -LiteralPath $CompilerDiagnosticsOutputPath)) {
        throw "Diagnosticos do compilador nao foram gerados: $CompilerDiagnosticsOutputPath"
    }

    exit 0
} catch {
    if ([string]::IsNullOrWhiteSpace($OutputPath)) {
        $OutputPath = Join-Path $RepoRoot 'code-review.md'
    }

    if ([string]::IsNullOrWhiteSpace($HtmlOutputPath)) {
        $HtmlOutputPath = [System.IO.Path]::ChangeExtension($OutputPath, '.html')
    }

    if ($Action -eq 'Resolve') {
        $outputDir = Split-Path -Parent $OutputPath
        if (-not [string]::IsNullOrWhiteSpace($outputDir)) {
            New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
        }
        "# Resolucao com Codex - $TaskCode`r`n`r`nErro ao resolver achados: $($_.Exception.Message)" |
            Set-Content -LiteralPath $OutputPath -Encoding UTF8
    } else {
        Write-ReviewFile "# Code review - $TaskCode`r`n`r`nErro ao executar code review: $($_.Exception.Message)"
    }
    exit 1
}
