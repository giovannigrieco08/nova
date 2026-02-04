import 'package:flutter/material.dart';

import '../../../../core/theme/nova_colors.dart';
import '../../../../core/theme/nova_radius.dart';
import '../../../../core/theme/nova_spacing.dart';

/// Skeleton placeholder for tutor cards during loading.
class TutorCardSkeleton extends StatefulWidget {
  const TutorCardSkeleton({super.key});

  @override
  State<TutorCardSkeleton> createState() => _TutorCardSkeletonState();
}

class _TutorCardSkeletonState extends State<TutorCardSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
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
        return Container(
          margin: const EdgeInsets.symmetric(
            horizontal: NovaSpacing.m,
            vertical: NovaSpacing.xs,
          ),
          padding: const EdgeInsets.all(NovaSpacing.m),
          decoration: BoxDecoration(
            color: NovaColors.card(context),
            borderRadius: NovaRadius.circularM,
            border: Border.all(color: NovaColors.border(context)),
          ),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: NovaColors.border(context)
                      .withValues(alpha: _animation.value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: NovaSpacing.m),
              // Info skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: NovaColors.border(context)
                            .withValues(alpha: _animation.value),
                        borderRadius: NovaRadius.circularXxs,
                      ),
                    ),
                    const SizedBox(height: NovaSpacing.xs),
                    // Class
                    Container(
                      width: 80,
                      height: 12,
                      decoration: BoxDecoration(
                        color: NovaColors.border(context)
                            .withValues(alpha: _animation.value),
                        borderRadius: NovaRadius.circularXxs,
                      ),
                    ),
                    const SizedBox(height: NovaSpacing.s),
                    // Bio
                    Container(
                      width: double.infinity,
                      height: 10,
                      decoration: BoxDecoration(
                        color: NovaColors.border(context)
                            .withValues(alpha: _animation.value),
                        borderRadius: NovaRadius.circularXxs,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: NovaSpacing.m),
              // Price skeleton
              Container(
                width: 50,
                height: 24,
                decoration: BoxDecoration(
                  color: NovaColors.border(context)
                      .withValues(alpha: _animation.value),
                  borderRadius: NovaRadius.circularS,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Loading skeleton for tutors list.
class TutorsListSkeleton extends StatelessWidget {
  const TutorsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: NovaSpacing.s),
      itemCount: 6,
      itemBuilder: (context, index) =>
          TutorCardSkeleton(key: ValueKey('skeleton_$index')),
    );
  }
}

/// Skeleton placeholder for subject list tiles.
class SubjectTileSkeleton extends StatefulWidget {
  final bool showDivider;

  const SubjectTileSkeleton({
    super.key,
    this.showDivider = true,
  });

  @override
  State<SubjectTileSkeleton> createState() => _SubjectTileSkeletonState();
}

class _SubjectTileSkeletonState extends State<SubjectTileSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.3, end: 0.6).animate(
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
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: NovaSpacing.m,
                vertical: NovaSpacing.m,
              ),
              child: Row(
                children: [
                  // Icon skeleton
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: NovaColors.border(context)
                          .withValues(alpha: _animation.value),
                      borderRadius: NovaRadius.circularS,
                    ),
                  ),
                  const SizedBox(width: NovaSpacing.m),
                  // Text skeleton
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 100,
                          height: 16,
                          decoration: BoxDecoration(
                            color: NovaColors.border(context)
                                .withValues(alpha: _animation.value),
                            borderRadius: NovaRadius.circularXxs,
                          ),
                        ),
                        const SizedBox(height: NovaSpacing.xs),
                        Container(
                          width: 180,
                          height: 12,
                          decoration: BoxDecoration(
                            color: NovaColors.border(context)
                                .withValues(alpha: _animation.value),
                            borderRadius: NovaRadius.circularXxs,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Icon(
                    Icons.chevron_right,
                    color: NovaColors.border(context)
                        .withValues(alpha: _animation.value),
                  ),
                ],
              ),
            ),
            if (widget.showDivider)
              Divider(
                height: 1,
                indent: NovaSpacing.m + 48 + NovaSpacing.m,
                color: NovaColors.border(context),
              ),
          ],
        );
      },
    );
  }
}

/// Loading skeleton for subjects list.
class SubjectsListSkeleton extends StatelessWidget {
  const SubjectsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 12,
      itemBuilder: (context, index) => SubjectTileSkeleton(
        key: ValueKey('subject_skeleton_$index'),
        showDivider: index < 11,
      ),
    );
  }
}
