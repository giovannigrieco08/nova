# Script to update design system constants in event creation files

$files = @(
    "lib\features\events\presentation\widgets\event_form.dart",
    "lib\features\events\presentation\widgets\image_picker_widget.dart"
)

foreach ($file in $files) {
    Write-Host "Updating $file..."

    $content = Get-Content $file -Raw

    # Replace imports
    $content = $content -replace "import '../../../../core/theme/nova_typography\.dart';", "import '../../../../core/theme/nova_text_styles.dart';"

    # Replace NovaTypography
    $content = $content -replace 'NovaTypography\.labelMedium', 'NovaTextStyles.body'
    $content = $content -replace 'NovaTypography\.bodySmall', 'NovaTextStyles.caption'
    $content = $content -replace 'NovaTypography\.bodyMedium', 'NovaTextStyles.body'

    # Replace NovaSpacing
    $content = $content -replace 'NovaSpacing\.large', 'NovaSpacing.l'
    $content = $content -replace 'NovaSpacing\.medium', 'NovaSpacing.m'
    $content = $content -replace 'NovaSpacing\.small', 'NovaSpacing.s'
    $content = $content -replace 'NovaSpacing\.xsmall', 'NovaSpacing.xs'

    # Replace NovaRadius with proper circular methods
    $content = $content -replace 'BorderRadius\.circular\(NovaRadius\.large\)', 'NovaRadius.circularL'
    $content = $content -replace 'BorderRadius\.circular\(NovaRadius\.medium\)', 'NovaRadius.circularM'
    $content = $content -replace 'BorderRadius\.circular\(NovaRadius\.m\)', 'NovaRadius.circularM'
    $content = $content -replace 'BorderRadius\.circular\(NovaRadius\.l\)', 'NovaRadius.circularL'

    # Replace NovaColors
    $content = $content -replace 'NovaColors\.backgroundSecondary\(context\)', 'NovaColors.surface(context)'
    $content = $content -replace 'NovaColors\.backgroundPrimary\(context\)', 'NovaColors.background(context)'

    Set-Content $file $content -NoNewline
    Write-Host "✅ Updated $file"
}

Write-Host "`n✅ All files updated successfully!"
