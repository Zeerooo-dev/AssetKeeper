import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class NavigationSurface extends StatelessWidget {
  const NavigationSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.scaffoldBackgroundColor;
    final ink = theme.colorScheme.onSurface;
    final highContrast = MediaQuery.highContrastOf(context);
    final tint = base.withValues(
      alpha: theme.brightness == Brightness.dark ? .82 : .90,
    );
    // Match JANITRA's frost only when controls stay readable on either backdrop.
    final frosted =
        !highContrast &&
        [Colors.black, Colors.white].every(
          (backdrop) =>
              AssetKeeperThemes.contrast(
                ink,
                Color.alphaBlend(tint, backdrop),
              ) >=
              4.5,
        );
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: frosted ? tint : base,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(
            alpha: highContrast ? 1 : .45,
          ),
          width: .5,
        ),
      ),
      child: Material(type: MaterialType.transparency, child: child),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: frosted
          ? BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: surface,
            )
          : surface,
    );
  }
}

class FloatingNavigation extends StatelessWidget {
  const FloatingNavigation({
    super.key,
    required this.selected,
    required this.onSelected,
    required this.icons,
    required this.labels,
  });
  final int selected;
  final ValueChanged<int> onSelected;
  final List<IconData> icons;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ink = theme.colorScheme.onSurface;
    final indicator = Color.alphaBlend(
      ink.withValues(alpha: .08),
      theme.scaffoldBackgroundColor,
    );
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: NavigationSurface(
        child: MediaQuery.textScalerOf(context).scale(1) < 1.5
            ? NavigationBarTheme(
                data: NavigationBarThemeData(
                  height: 70,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  indicatorColor: indicator,
                  iconTheme: WidgetStatePropertyAll(IconThemeData(color: ink)),
                  labelTextStyle: WidgetStateProperty.resolveWith(
                    (states) => TextStyle(
                      color: ink,
                      fontSize: 12,
                      fontWeight: states.contains(WidgetState.selected)
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
                child: NavigationBar(
                  selectedIndex: selected,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                  animationDuration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  onDestinationSelected: onSelected,
                  destinations: [
                    for (var i = 0; i < labels.length; i++)
                      NavigationDestination(
                        icon: Icon(icons[i]),
                        label: labels[i],
                      ),
                  ],
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) => Wrap(
                  children: [
                    for (var i = 0; i < labels.length; i++)
                      SizedBox(
                        width: constraints.maxWidth / 2,
                        child: Semantics(
                          selected: i == selected,
                          child: TextButton(
                            onPressed: () => onSelected(i),
                            style: TextButton.styleFrom(
                              foregroundColor: ink,
                              backgroundColor: i == selected ? indicator : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [Icon(icons[i]), Text(labels[i])],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
