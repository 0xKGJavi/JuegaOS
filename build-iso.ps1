$ErrorActionPreference = 'Stop'

$owner = '0xKGJavi'
$repository = 'JuegaOS'
$workflow = 'build-juegaos-iso.yml'
$branch = 'main'
$outputDirectory = Join-Path $PSScriptRoot 'out'
$actionsUrl = "https://github.com/$owner/$repository/actions/workflows/$workflow"
$apiBase = "https://api.github.com/repos/$owner/$repository"
$oldInteractive = $env:GCM_INTERACTIVE
$oldTerminalPrompt = $env:GIT_TERMINAL_PROMPT
$env:GCM_INTERACTIVE = 'never'
$env:GIT_TERMINAL_PROMPT = '0'

function Get-GitHubToken {
    $credentialText = "protocol=https`nhost=github.com`n`n" | git -C $PSScriptRoot credential fill 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw 'No hay credenciales de GitHub guardadas en Git. Inicia sesion en GitHub desde Git o Visual Studio Code y vuelve a intentarlo.'
    }

    foreach ($line in $credentialText) {
        if ($line -match '^password=(.+)$') {
            return $Matches[1]
        }
    }

    throw 'Git no devolvio un token de GitHub. Inicia sesion en GitHub desde Git o Visual Studio Code y vuelve a intentarlo.'
}

function Invoke-GitHubApi {
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][hashtable]$Headers,
        [string]$Method = 'Get',
        [object]$Body
    )

    $request = @{
        Uri     = $Uri
        Headers = $Headers
        Method  = $Method
    }
    if ($null -ne $Body) {
        $request.ContentType = 'application/json'
        $request.Body = $Body | ConvertTo-Json -Compress
    }
    Invoke-RestMethod @request
}

function Get-ResponseStatusCode {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)
    if ($ErrorRecord.Exception.Response -and $ErrorRecord.Exception.Response.StatusCode) {
        return [int]$ErrorRecord.Exception.Response.StatusCode
    }
    return 0
}

try {
    $token = Get-GitHubToken
    $headers = @{
        Authorization = "Bearer $token"
        Accept = 'application/vnd.github+json'
        'X-GitHub-Api-Version' = '2022-11-28'
    }

    Write-Host "Comprobando acceso a $owner/$repository ..."
    $repo = Invoke-GitHubApi -Uri $apiBase -Headers $headers
    $user = Invoke-GitHubApi -Uri 'https://api.github.com/user' -Headers $headers
    if ($user.login -ne $owner) {
        throw "El inicio de sesion de Git pertenece a '$($user.login)', no a '$owner'."
    }

    $workflowUri = "$apiBase/actions/workflows/$workflow"
    $workflowInfo = Invoke-GitHubApi -Uri $workflowUri -Headers $headers
    if ($workflowInfo.state -ne 'active') {
        throw 'El workflow de GitHub Actions no esta activo.'
    }

    $ref = Invoke-GitHubApi -Uri "$apiBase/git/ref/heads/$branch" -Headers $headers
    $headSha = $ref.object.sha
    $dispatchTime = [DateTimeOffset]::UtcNow
    $dispatchBody = @{ ref = $branch }
    $dispatchResponse = Invoke-WebRequest `
        -Uri "$workflowUri/dispatches" `
        -Headers $headers `
        -Method Post `
        -ContentType 'application/json' `
        -Body ($dispatchBody | ConvertTo-Json -Compress) `
        -UseBasicParsing
    if ([int]$dispatchResponse.StatusCode -ne 204) {
        throw "GitHub no acepto el inicio de la compilacion (HTTP $($dispatchResponse.StatusCode))."
    }

    Write-Host 'Compilacion iniciada en GitHub Actions. Esperando a que termine...'
    Write-Host $actionsUrl
    $run = $null
    $deadline = [DateTimeOffset]::UtcNow.AddHours(6)
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        Start-Sleep -Seconds 20
        $runs = Invoke-GitHubApi `
            -Uri "$apiBase/actions/workflows/$workflow/runs?branch=$branch&event=workflow_dispatch&per_page=20" `
            -Headers $headers
        $run = $runs.workflow_runs |
            Where-Object {
                $_.head_sha -eq $headSha -and
                [DateTimeOffset]::Parse($_.created_at) -ge $dispatchTime.AddSeconds(-15)
            } |
            Sort-Object created_at -Descending |
            Select-Object -First 1

        if ($null -eq $run) {
            Write-Host 'Esperando que GitHub registre la ejecucion...'
            continue
        }
        Write-Host "Estado: $($run.status)  (ejecucion #$($run.run_number))"
        if ($run.status -eq 'completed') {
            break
        }
    }

    if ($null -eq $run -or $run.status -ne 'completed') {
        throw "La compilacion aun no termino. Consulta el estado aqui: $actionsUrl"
    }
    if ($run.conclusion -ne 'success') {
        throw "La compilacion termino con resultado '$($run.conclusion)'. Consulta los detalles aqui: $($run.html_url)"
    }

    $artifactList = Invoke-GitHubApi `
        -Uri "$apiBase/actions/runs/$($run.id)/artifacts?per_page=100" `
        -Headers $headers
    $artifact = $artifactList.artifacts |
        Where-Object { $_.name -eq 'juegaos-iso' -and -not $_.expired } |
        Select-Object -First 1
    if ($null -eq $artifact) {
        throw "La ejecucion termino correctamente, pero no se encontro el artefacto ISO. Consulta: $($run.html_url)"
    }

    New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    $zipPath = Join-Path $outputDirectory 'juegaos-iso.zip'
    $downloadUri = "$apiBase/actions/artifacts/$($artifact.id)/zip"
    try {
        Invoke-WebRequest -Uri $downloadUri -Headers $headers -OutFile $zipPath -UseBasicParsing -MaximumRedirection 0
    }
    catch {
        $response = $_.Exception.Response
        if ((Get-ResponseStatusCode $_) -notin @(301, 302, 303, 307, 308) -or $null -eq $response.Headers.Location) {
            throw 'No se pudo descargar el artefacto de GitHub Actions.'
        }
        $redirectUri = [Uri]$response.Headers.Location
        if ($redirectUri.Scheme -ne 'https') {
            throw 'GitHub devolvio una direccion de descarga que no usa HTTPS.'
        }
        Invoke-WebRequest -Uri $redirectUri.AbsoluteUri -OutFile $zipPath -UseBasicParsing
    }

    Expand-Archive -LiteralPath $zipPath -DestinationPath $outputDirectory -Force
    Remove-Item -LiteralPath $zipPath -Force

    $isoFiles = @(Get-ChildItem -LiteralPath $outputDirectory -Filter '*.iso' -File)
    $checksumFile = Join-Path $outputDirectory 'SHA256SUMS'
    if ($isoFiles.Count -ne 1 -or -not (Test-Path -LiteralPath $checksumFile)) {
        throw "El artefacto descargado no contiene exactamente una ISO y su SHA256SUMS. Revisa $($run.html_url)"
    }

    $checksumLine = Get-Content -LiteralPath $checksumFile |
        Where-Object { $_ -match [regex]::Escape($isoFiles[0].Name) } |
        Select-Object -First 1
    if ($checksumLine -notmatch '^([0-9a-fA-F]{64})\s+\*?(.+)$') {
        throw 'El archivo SHA256SUMS tiene un formato inesperado.'
    }
    $expectedHash = $Matches[1].ToLowerInvariant()
    $actualHash = (Get-FileHash -LiteralPath $isoFiles[0].FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $expectedHash) {
        throw 'La comprobacion SHA-256 de la ISO ha fallado.'
    }

    Write-Host ''
    Write-Host "ISO lista: $($isoFiles[0].FullName)"
    Write-Host "SHA-256: $actualHash"
    Write-Host "Ejecucion: $($run.html_url)"
}
catch {
    Write-Error $_.Exception.Message
    exit 1
}
finally {
    $env:GCM_INTERACTIVE = $oldInteractive
    $env:GIT_TERMINAL_PROMPT = $oldTerminalPrompt
}
