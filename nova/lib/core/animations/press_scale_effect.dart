import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nova/core/theme/nova_colors.dart';

/// A widget that scales down slightly when pressed, providing tactile feedback.
///
/// This creates an iOS-style button press effect that makes interactions
/// feel responsive and satisfying.
///
/// Usage:
/// ```dart
/// PressScaleEffect(
///   onTap: () => print('Tapped!'),
///   child: Container(
///     padding: EdgeInsets.all(16),
///     child: Text('Tap me'),
///   ),
/// )
/// ```
class PressScaleEffect extends StatefulWidget {
  /// The widget to apply the effect to.
  final Widget child;

  /// Callback when the widget is tapped.
  final VoidCallback? onTap;

  /// Callback when the widget is long-pressed.
  final VoidCallback? onLongPress;

  /// Scale factor when pressed (0.95 = 5% smaller).
  final double pressedScale;

  /// Duration of the scale animation.
  final Duration duration;

  /// Whether to trigger haptic feedback on tap.
  final bool hapticFeedback;

  /// Type of haptic feedback to use.
  final HapticType hapticType;

  /// Whether the effect is enabled.
  final bool enabled;

  const PressScaleEffect({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.95,
    this.duration = const Duration(milliseconds: 100),
    this.hapticFeedback = true,
    this.hapticType = HapticType.light,
    this.enabled = true,
  });

  @override
  State<PressScaleEffect> createState() => _PressScaleEffectState();
}

class _PressScaleEffectState extends State<PressScaleEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.pressedScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (!widget.enabled) return;
    _controller.forward();
  }

  void _onPointerUp(PointerUpEvent event) {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  void _handleTap() {
    if (!widget.enabled) return;

    if (widget.hapticFeedback) {
      _triggerHaptic();
    }

    widget.onTap?.call();
  }

  void _handleLongPress() {
    if (!widget.enabled) return;

    if (widget.hapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    widget.onLongPress?.call();
  }

  void _triggerHaptic() {
    switch (widget.hapticType) {
      case HapticType.light:
        HapticFeedback.lightImpact();
        break;
      case HapticType.medium:
        HapticFeedback.mediumImpact();
        break;
      case HapticType.heavy:
        HapticFeedback.heavyImpact();
        break;
      case HapticType.selection:
        HapticFeedback.selectionClick();
        break;
      case HapticType.none:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: GestureDetector(
        onTap: widget.onTap != null ? _handleTap : null,
        onLongPress: widget.onLongPress != null ? _handleLongPress : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: child,
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}

/// Type of haptic feedback to trigger.
enum HapticType {
  light,
  medium,
  heavy,
  selection,
  none,
}

/// A button-style widget with built-in press scale effect.
///
/// Combines the scale effect with common button styling.
///
/// Usage:
/// ```dart
/// ScaleButton(
///   onTap: () => print('Button tapped'),
///   child: Text('Click me'),
/// )
/// ```
class ScaleButton extends StatelessWidget {
  /// The button content.
  final Widget child;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Callback when long-pressed.
  final VoidCallback? onLongPress;

  /// Padding inside the button.
  final EdgeInsetsGeometry padding;

  /// Background decoration.
  final BoxDecoration? decoration;

  /// Scale when pressed.
  final double pressedScale;

  /// Whether the button is enabled.
  final bool enabled;

  const ScaleButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    this.decoration,
    this.pressedScale = 0.95,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return PressScaleEffect(
      onTap: onTap,
      onLongPress: onLongPress,
      pressedScale: pressedScale,
      enabled: enabled,
      child: Container(
        padding: padding,
        decoration: decoration,
        child: child,
      ),
    );
  }
}

/// A card widget with built-in press scale effect.
///
/// Perfect for list items, event cards, and other tappable containers.
///
/// Usage:
/// ```dart
/// ScaleCard(
///   onTap: () => Navigator.push(...),
///   child: EventContent(...),
/// )
/// ```
class ScaleCard extends StatelessWidget {
  /// The card content.
  final Widget child;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Callback when long-pressed.
  final VoidCallback? onLongPress;

  /// Padding inside the card.
  final EdgeInsetsGeometry padding;

  /// Margin around the card.
  final EdgeInsetsGeometry margin;

  /// Border radius.
  final double borderRadius;

  /// Card elevation.
  final double elevation;

  /// Background color.
  final Color? backgroundColor;

  /// Scale when pressed.
  final double pressedScale;

  /// Whether the card is enabled.
  final bool enabled;

  const ScaleCard({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.padding = EdgeInsets.zero,
    this.margin = EdgeInsets.zero,
    this.borderRadius = 12,
    this.elevation = 0,
    this.backgroundColor,
    this.pressedScale = 0.98,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDark ? NovaColors.cardDark : NovaColors.backgroundLight);

    return Padding(
      padding: margin,
      child: PressScaleEffect(
        onTap: onTap,
        onLongPress: onLongPress,
        pressedScale: pressedScale,
        enabled: enabled && (onTap != null || onLongPress != null),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: elevation > 0
                ? [
                    BoxShadow(
                      color: NovaColors.textPrimaryLight.withValues(alpha: 0.1),
                      blurRadius: elevation * 2,
                      offset: Offset(0, elevation),
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// An icon button with press scale effect.
///
/// Usage:
/// ```dart
/// ScaleIconButton(
///   icon: Icons.favorite,
///   onTap: () => toggleLike(),
/// )
/// ```
class ScaleIconButton extends StatelessWidget {
  /// The icon to display.
  final IconData icon;

  /// Callback when tapped.
  final VoidCallback? onTap;

  /// Icon size.
  final double size;

  /// Icon color.
  final Color? color;

  /// Padding around the icon (increases tap target).
  final EdgeInsetsGeometry padding;

  /// Scale when pressed.
  final double pressedScale;

  /// Whether to show haptic feedback.
  final bool hapticFeedback;

  const ScaleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 24,
    this.color,
    this.padding = const EdgeInsets.all(8),
    this.pressedScale = 0.85,
    this.hapticFeedback = true,
  });

  @override
  Widget build(BuildContext context) {
    return PressScaleEffect(
      onTap: onTap,
      pressedScale: pressedScale,
      hapticFeedback: hapticFeedback,
      child: Padding(
        padding: padding,
        child: Icon(
          icon,
          size: size,
          color: color ?? Theme.of(context).iconTheme.color,
        ),
      ),
    );
  }
}
