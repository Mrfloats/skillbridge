import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/models.dart';
import 'common.dart';

/// A section of the app, listed in the side menu.
class AppNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  const AppNavItem({required this.icon, required this.selectedIcon, required this.label});
}

/// Lets the pages inside a shell open the shell's side menu.
class ShellMenu extends InheritedWidget {
  final VoidCallback open;
  const ShellMenu({super.key, required this.open, required super.child});

  /// A menu button for a page's top bar, or null when the page is not inside a shell
  /// (for example when it was pushed on its own), so the bar shows its usual back button.
  /// Set [onHero] for the dark header panels, where the button needs a light style.
  static Widget? button(BuildContext context, {bool onHero = false}) {
    final menu = context.getInheritedWidgetOfExactType<ShellMenu>();
    if (menu == null) return null;
    return IconButton(
      icon: Icon(Icons.menu_rounded, color: onHero ? Colors.white : null),
      tooltip: MaterialLocalizations.of(context).openAppDrawerTooltip,
      style: onHero ? IconButton.styleFrom(backgroundColor: Colors.white.withAlpha(26), hoverColor: Colors.white.withAlpha(46)) : null,
      onPressed: menu.open,
    );
  }

  @override
  bool updateShouldNotify(ShellMenu oldWidget) => false;
}

/// The side menu: the user's photo, name and rating at the top, then the app's sections.
/// Tapping the top row opens the profile.
class AppDrawer extends StatelessWidget {
  final AppUser user;
  final List<AppNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback onProfile;

  /// Starts listening to the user's rating. The menu calls it each time it opens, because
  /// the menu is rebuilt then. Null for users who are not rated, who see "View profile" instead.
  final Stream<RatingSummary?> Function()? rating;

  /// Pages that open on top, such as Settings, listed under the sections.
  final List<AppDrawerLink> links;

  /// The button at the bottom that switches between client and provider mode.
  final AppDrawerLink? modeSwitch;

  const AppDrawer({
    super.key,
    required this.user,
    required this.items,
    required this.index,
    required this.onChanged,
    required this.onProfile,
    this.rating,
    this.links = const [],
    this.modeSwitch,
  });

  void _go(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = context.palette;
    return Drawer(
      backgroundColor: dark ? Theme.of(context).colorScheme.surfaceContainerHigh : palette.heroStart,
      child: SafeArea(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _Header(user: user, rating: rating, onTap: () => _go(context, onProfile)),
          Divider(height: 1, color: Colors.white.withAlpha(30)),
          // Scrolls on short screens, where the full list would not fit.
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(vertical: 12), children: [
              for (var i = 0; i < items.length; i++) _MenuItem(item: items[i], selected: i == index, onTap: () => _go(context, () => onChanged(i))),
              if (links.isNotEmpty) Divider(height: 24, indent: 24, endIndent: 24, color: Colors.white.withAlpha(30)),
              for (final link in links)
                _MenuItem(
                  item: AppNavItem(icon: link.icon, selectedIcon: link.icon, label: link.label),
                  selected: false,
                  compact: true,
                  count: link.count,
                  onTap: () => _go(context, link.onTap),
                ),
            ]),
          ),
          if (modeSwitch case final mode?)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.accent,
                  foregroundColor: palette.onAccent,
                  minimumSize: const Size.fromHeight(54),
                  textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                onPressed: () => _go(context, mode.onTap),
                icon: Icon(mode.icon),
                label: Text(mode.label),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Header extends StatefulWidget {
  final AppUser user;
  final Stream<RatingSummary?> Function()? rating;
  final VoidCallback onTap;
  const _Header({required this.user, required this.rating, required this.onTap});

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  late final Stream<RatingSummary?>? _rating = widget.rating?.call();

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final t = Theme.of(context).textTheme;
    final muted = t.bodyLarge?.copyWith(color: Colors.white.withAlpha(190));
    final stream = _rating;
    return Semantics(
      button: true,
      label: 'Open your profile',
      child: InkWell(
        onTap: widget.onTap,
        splashColor: Colors.white.withAlpha(30),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 12, 24),
          child: Row(children: [
            Avatar(url: user.photoUrl, name: user.fullName, radius: 34),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(user.fullName, style: t.titleLarge?.copyWith(color: Colors.white), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                if (stream == null)
                  Text('View profile', style: muted)
                else
                  StreamBuilder<RatingSummary?>(
                    stream: stream,
                    builder: (context, snap) {
                      final r = snap.data;
                      if (r == null || r.count == 0) return Text(snap.connectionState == ConnectionState.waiting ? '' : 'No ratings yet', style: muted);
                      return _Stars(r);
                    },
                  ),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withAlpha(220), size: 30),
          ]),
        ),
      ),
    );
  }
}

class _Stars extends StatelessWidget {
  final RatingSummary rating;
  const _Stars(this.rating);

  @override
  Widget build(BuildContext context) {
    final avg = rating.average;
    return Row(children: [
      for (var i = 1; i <= 5; i++)
        Icon(
          avg >= i ? Icons.star_rounded : (avg >= i - 0.5 ? Icons.star_half_rounded : Icons.star_outline_rounded),
          size: 22,
          color: context.palette.star,
        ),
      const SizedBox(width: 6),
      Flexible(
        child: Text(
          '${avg.toStringAsFixed(1)} (${rating.count})',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withAlpha(190)),
          maxLines: 1,
        ),
      ),
    ]);
  }
}

/// A page in the side menu that opens on top of the current section.
class AppDrawerLink {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Starts listening to a number to show beside the label, such as unread notifications.
  final Stream<int> Function()? count;
  const AppDrawerLink({required this.icon, required this.label, required this.onTap, this.count});
}

class _MenuItem extends StatefulWidget {
  final AppNavItem item;
  final bool selected;
  final bool compact;
  final Stream<int> Function()? count;
  final VoidCallback onTap;
  const _MenuItem({required this.item, required this.selected, required this.onTap, this.compact = false, this.count});

  @override
  State<_MenuItem> createState() => _MenuItemState();
}

class _MenuItemState extends State<_MenuItem> {
  late final Stream<int>? _count = widget.count?.call();

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final selected = widget.selected;
    final palette = context.palette;
    final color = selected ? palette.onAccent : Colors.white.withAlpha(215);
    final count = _count;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Semantics(
        selected: selected,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(gradient: selected ? palette.accentGradient : null, borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(18),
              hoverColor: Colors.white.withAlpha(selected ? 0 : 18),
              splashColor: Colors.white.withAlpha(30),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: widget.compact ? 12 : 15),
                child: Row(children: [
                  Icon(selected ? item.selectedIcon : item.icon, color: color),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(item.label,
                        style: (widget.compact ? Theme.of(context).textTheme.titleSmall : Theme.of(context).textTheme.titleMedium)
                            ?.copyWith(color: color, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
                  ),
                  if (count != null)
                    StreamBuilder<int>(
                      stream: count,
                      builder: (context, snap) {
                        final n = snap.data ?? 0;
                        if (n == 0) return const SizedBox.shrink();
                        return Semantics(
                          label: '$n new',
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: palette.accent, borderRadius: BorderRadius.circular(10)),
                            child: Text(n > 99 ? '99+' : '$n', style: TextStyle(color: palette.onAccent, fontWeight: FontWeight.w800, fontSize: 12)),
                          ),
                        );
                      },
                    ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
