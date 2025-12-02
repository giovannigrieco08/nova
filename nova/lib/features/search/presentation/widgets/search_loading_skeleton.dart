/// Search loading skeleton widget
///
/// Shimmer loading state for search results.

import 'package:flutter/material.dart';
import 'package:nova/core/theme/nova_colors.dart';
import 'package:nova/core/theme/nova_spacing.dart';
import 'package:nova/core/theme/nova_radius.dart';

/// Shimmer loading skeleton for search results
class SearchLoadingSkeleton extends StatefulWidget {
  const SearchLoadingSkeleton({super.key});

  @override
  State<SearchLoadingSkeleton> createState() => _SearchLoadingSkeletonState();
}

class _SearchLoadingSkeletonState extends State<SearchLoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _animation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(NovaSpacing.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section header skeleton
              _buildSectionHeader(),
              const SizedBox(height: NovaSpacing.s),
              // Event skeletons
              ...List.generate(3, (_) => _buildEventSkeleton()),
              const SizedBox(height: NovaSpacing.l),
              // Second section header
              _buildSectionHeader(),
              const SizedBox(height: NovaSpacing.s),
              // Profile skeletons
              ...List.generate(3, (_) => _buildProfileSkeleton()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        _shimmerBox(width: 60, height: 18),
        const SizedBox(width: NovaSpacing.xs),
        _shimmerBox(width: 24, height: 18, borderRadius: 9),
      ],
    );
  }

  Widget _buildEventSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(NovaSpacing.s),
        decoration: BoxDecoration(
          color: NovaColors.surfaceLight,
          borderRadius: BorderRadius.circular(NovaRadius.medium),
          border: Border.all(color: NovaColors.borderLight),
        ),
        child: Row(
          children: [
            // Thumbnail skeleton
            _shimmerBox(width: 56, height: 56, borderRadius: NovaRadius.small),
            const SizedBox(width: NovaSpacing.s),
            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(width: double.infinity, height: 16),
                  const SizedBox(height: NovaSpacing.xs),
                  _shimmerBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSkeleton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: NovaSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(NovaSpacing.s),
        decoration: BoxDecoration(
          color: NovaColors.surfaceLight,
          borderRadius: BorderRadius.circular(NovaRadius.medium),
          border: Border.all(color: NovaColors.borderLight),
        ),
        child: Row(
          children: [
            // Avatar skeleton
            _shimmerBox(width: 48, height: 48, borderRadius: 24),
            const SizedBox(width: NovaSpacing.s),
            // Content skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(width: 140, height: 16),
                  const SizedBox(height: NovaSpacing.xs),
                  _shimmerBox(width: 80, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double borderRadius = 4,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: NovaColors.dividerLight.withOpacity(_animation.value),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}
