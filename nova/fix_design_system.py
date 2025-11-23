#!/usr/bin/env python3
"""
Script to fix design system references in event creation files
"""
import re

files_to_fix = [
    r"lib\features\events\presentation\screens\event_creation_screen.dart",
    r"lib\features\events\presentation\screens\event_detail_screen.dart",
    r"lib\features\events\presentation\widgets\event_form.dart",
    r"lib\features\events\presentation\widgets\image_picker_widget.dart",
    r"lib\features\events\presentation\widgets\event_status_badge.dart",
]

# Define all replacements
replacements = [
    # NovaTypography → NovaTextStyles (specific mappings first)
    (r'NovaTypography\.labelMedium', 'NovaTextStyles.body'),
    (r'NovaTypography\.bodySmall', 'NovaTextStyles.caption'),
    (r'NovaTypography\.bodyMedium', 'NovaTextStyles.body'),
    (r'NovaTypography\.button', 'NovaTextStyles.button'),
    (r'NovaTypography\.caption', 'NovaTextStyles.caption'),
    (r'NovaTypography\.body', 'NovaTextStyles.body'),
    (r'NovaTypography\.h2', 'NovaTextStyles.h2'),
    (r'NovaTypography\.h3', 'NovaTextStyles.h3'),

    # NovaSpacing
    (r'NovaSpacing\.large', 'NovaSpacing.l'),
    (r'NovaSpacing\.medium', 'NovaSpacing.m'),
    (r'NovaSpacing\.small', 'NovaSpacing.s'),
    (r'NovaSpacing\.xsmall', 'NovaSpacing.xs'),

    # NovaRadius with BorderRadius.circular
    (r'BorderRadius\.circular\(NovaRadius\.large\)', 'NovaRadius.circularL'),
    (r'BorderRadius\.circular\(NovaRadius\.medium\)', 'NovaRadius.circularM'),
    (r'BorderRadius\.circular\(NovaRadius\.l\)', 'NovaRadius.circularL'),
    (r'BorderRadius\.circular\(NovaRadius\.m\)', 'NovaRadius.circularM'),

    # NovaRadius with Radius.circular (for individual corners)
    (r'Radius\.circular\(NovaRadius\.large\)', 'Radius.circular(NovaRadius.l)'),
    (r'Radius\.circular\(NovaRadius\.medium\)', 'Radius.circular(NovaRadius.m)'),

    # NovaColors
    (r'NovaColors\.backgroundSecondary\(context\)', 'NovaColors.surface(context)'),
    (r'NovaColors\.backgroundPrimary\(context\)', 'NovaColors.background(context)'),
]

for file_path in files_to_fix:
    print(f"Processing {file_path}...")

    # Read file
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    original_content = content

    # Apply all replacements
    for pattern, replacement in replacements:
        content = re.sub(pattern, replacement, content)

    # Write back if changed
    if content != original_content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"  ✓ Updated {file_path}")
    else:
        print(f"  - No changes needed in {file_path}")

print("\n✓ All files processed!")
