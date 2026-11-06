import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'motion.dart';

class AppNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const AppNavItem({required this.icon, required this.selectedIcon, required this.label});
}

/// Floating bottom navigation with an amber pill that slides to the selected tab.
class AppNavBar extends StatelessWidget {
  final List<AppNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  const AppNavBar({super.key, required this.items, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? Theme.of(context).colorScheme.surfaceContainerHigh : palette.heroStart;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 68,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [BoxShadow(color: palette.shadow.withAlpha(70), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        child: LayoutBuilder(builder: (context, box) {
          final width = box.maxWidth / items.length;
          return Stack(children: [
            AnimatedPositioned(
              duration: Motion.reduced(context) ? Duration.zero : const Duration(milliseconds: 380),
              curve: Motion.overshoot,
              left: width * index,
              top: 0,
              bottom: 0,
              width: width,
              child: Container(decoration: BoxDecoration(gradient: palette.accentGradient, borderRadius: BorderRadius.circular(20))),
            ),
            Row(children: [
              for (var i = 0; i < items.length; i++)
                Expanded(child: _NavTab(item: items[i], selected: i == index, onTap: () => onChanged(i))),
            ]),
          ]);
        }),
      ),
    );
  }
}

class _NavTab extends StatefulWidget {
  final AppNavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavTab({required this.item, required this.selected, required this.onTap});

  @override
  State<_NavTab> createState() => _NavTabState();
}

class _NavTabState extends State<_NavTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = widget.selected ? palette.onAccent : Colors.white.withAlpha(_hovered ? 255 : 190);
    final reduced = Motion.reduced(context);
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.item.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(20),
            hoverColor: Colors.white.withAlpha(widget.selected ? 0 : 18),
            splashColor: Colors.white.withAlpha(30),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              AnimatedScale(
                scale: reduced ? 1 : (_hovered ? 1.14 : (widget.selected ? 1.04 : 1)),
                duration: Motion.medium,
                curve: Motion.overshoot,
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  child: Icon(
                    widget.selected ? widget.item.selectedIcon : widget.item.icon,
                    key: ValueKey(widget.selected),
                    size: 23,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedDefaultTextStyle(
                  duration: Motion.fast,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: color,
                        fontSize: 11,
                        fontWeight: widget.selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                  child: Text(widget.item.label, maxLines: 1),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
