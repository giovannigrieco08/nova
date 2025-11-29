# PowerShell script to fix NovaColors function calls
# Adds (context) to all NovaColors method calls that are missing it

Write-Host "Starting color function call fixes..." -ForegroundColor Cyan

$profilePath = "lib\features\profile"
$fixedCount = 0

# Pattern replacements
$replacements = @{
    'NovaColors\.textPrimary,' = 'NovaColors.textPrimary(context),'
    'NovaColors\.textSecondary,' = 'NovaColors.textSecondary(context),'
    'NovaColors\.textTertiary,' = 'NovaColors.textTertiary(context),'
    'NovaColors\.backgroundPrimary,' = 'NovaColors.backgroundPrimary(context),'
    'NovaColors\.backgroundSecondary,' = 'NovaColors.backgroundSecondary(context),'
    'NovaColors\.backgroundTertiary,' = 'NovaColors.backgroundTertiary(context),'
    'NovaColors\.borderPrimary,' = 'NovaColors.borderPrimary(context),'
    'NovaColors\.error,' = 'NovaColors.error(context),'
    'NovaColors\.success,' = 'NovaColors.success(context),'
    'NovaColors\.warning,' = 'NovaColors.warning(context),'
    'NovaColors\.divider,' = 'NovaColors.divider(context),'
    'NovaColors\.primary,' = 'NovaColors.primary(context),'
    'NovaColors\.surface,' = 'NovaColors.surface(context),'

    'NovaColors\.textPrimary\)' = 'NovaColors.textPrimary(context))'
    'NovaColors\.textSecondary\)' = 'NovaColors.textSecondary(context))'
    'NovaColors\.textTertiary\)' = 'NovaColors.textTertiary(context))'
    'NovaColors\.backgroundPrimary\)' = 'NovaColors.backgroundPrimary(context))'
    'NovaColors\.backgroundSecondary\)' = 'NovaColors.backgroundSecondary(context))'
    'NovaColors\.backgroundTertiary\)' = 'NovaColors.backgroundTertiary(context))'
    'NovaColors\.borderPrimary\)' = 'NovaColors.borderPrimary(context))'
    'NovaColors\.error\)' = 'NovaColors.error(context))'
    'NovaColors\.success\)' = 'NovaColors.success(context))'
    'NovaColors\.divider\)' = 'NovaColors.divider(context))'

    'NovaColors\.error\.withOpacity' = 'NovaColors.error(context).withOpacity'
}

Get-ChildItem -Path $profilePath -Filter "*.dart" -Recurse | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $originalContent = $content

    foreach ($pattern in $replacements.Keys) {
        $replacement = $replacements[$pattern]
        $content = $content -replace $pattern, $replacement
    }

    if ($content -ne $originalContent) {
        Set-Content -Path $_.FullName -Value $content -NoNewline
        Write-Host "Fixed: $($_.Name)" -ForegroundColor Green
        $fixedCount++
    }
}

Write-Host "`nComplete! Fixed $fixedCount files" -ForegroundColor Cyan
