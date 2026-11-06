import 'package:flutter/material.dart';

import '../../widgets/common.dart';

/// Shared layout for the sign-in screens: a teal header that scrolls away,
/// with the form fields rising in one after another below it.
class AuthScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final List<Widget> actions;
  final GlobalKey<FormState>? formKey;
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.actions = const [], this.formKey});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = HeroScrollView(
      hero: HeroPanel(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 48,
            child: Row(children: [
              if (Navigator.canPop(context)) const BackButton(color: Colors.white) else const SizedBox(width: 12),
              const BrandLogo(height: 36),
              const Spacer(),
              ...actions,
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Reveal(child: Text(title, style: t.displaySmall?.copyWith(color: Colors.white))),
              const SizedBox(height: 8),
              Reveal(index: 1, child: Text(subtitle, style: t.bodyLarge?.copyWith(color: Colors.white.withAlpha(205)))),
            ]),
          ),
        ]),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < children.length; i++) Reveal(index: i + 1, child: children[i]),
          ]),
        ),
      ],
    );
    return Scaffold(body: formKey == null ? list : Form(key: formKey, child: list));
  }
}
