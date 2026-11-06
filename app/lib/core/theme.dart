import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colours outside the Material scheme: the deep teal hero gradient, the amber
/// accent and the semantic money, warning and rating colours.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color heroStart;
  final Color heroEnd;
  final Color accent;
  final Color onAccent;
  final Color success;
  final Color warning;
  final Color star;
  final Color shadow;

  const AppPalette({
    required this.heroStart,
    required this.heroEnd,
    required this.accent,
    required this.onAccent,
    required this.success,
    required this.warning,
    required this.star,
    required this.shadow,
  });

  LinearGradient get heroGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [heroStart, heroEnd],
      );

  LinearGradient get accentGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [accent, Color.lerp(accent, const Color(0xFFF6CC7E), 0.6)!],
      );

  @override
  AppPalette copyWith({
    Color? heroStart,
    Color? heroEnd,
    Color? accent,
    Color? onAccent,
    Color? success,
    Color? warning,
    Color? star,
    Color? shadow,
  }) =>
      AppPalette(
        heroStart: heroStart ?? this.heroStart,
        heroEnd: heroEnd ?? this.heroEnd,
        accent: accent ?? this.accent,
        onAccent: onAccent ?? this.onAccent,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        star: star ?? this.star,
        shadow: shadow ?? this.shadow,
      );

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      heroStart: Color.lerp(heroStart, other.heroStart, t)!,
      heroEnd: Color.lerp(heroEnd, other.heroEnd, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      onAccent: Color.lerp(onAccent, other.onAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      star: Color.lerp(star, other.star, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}

/// Material 3 theme (SRS 4.1): the teal and amber of the SkillBridge logo on cool neutrals.
class AppTheme {
  static const bodyFont = 'PlusJakartaSans';
  static const displayFont = 'BricolageGrotesque';

  static const _lightPalette = AppPalette(
    heroStart: Color(0xFF0B3F45),
    heroEnd: Color(0xFF0F6E6E),
    accent: Color(0xFFE8A33D),
    onAccent: Color(0xFF0B3F45),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    star: Color(0xFFE8A33D),
    shadow: Color(0xFF0B3F45),
  );

  static const _darkPalette = AppPalette(
    heroStart: Color(0xFF0A3338),
    heroEnd: Color(0xFF0C5A5C),
    accent: Color(0xFFE8A33D),
    onAccent: Color(0xFF0B3F45),
    success: Color(0xFF4ADE80),
    warning: Color(0xFFFBBF24),
    star: Color(0xFFF0B458),
    shadow: Color(0xFF000000),
  );

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF0F6E6E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFBFE5E1),
    onPrimaryContainer: Color(0xFF0B3F45),
    secondary: Color(0xFF0B3F45),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDDF1EF),
    onSecondaryContainer: Color(0xFF0B3F45),
    tertiary: Color(0xFFA85F0A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFFBE9CC),
    onTertiaryContainer: Color(0xFF5F3705),
    error: Color(0xFFCF2A36),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFFE2E4),
    onErrorContainer: Color(0xFF7F1019),
    surface: Color(0xFFF5F9F8),
    onSurface: Color(0xFF0B2B2F),
    onSurfaceVariant: Color(0xFF4F6C6F),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFEEF5F4),
    surfaceContainer: Color(0xFFE7F0EF),
    surfaceContainerHigh: Color(0xFFE0EBEA),
    surfaceContainerHighest: Color(0xFFD8E5E4),
    outline: Color(0xFF6F8A8C),
    outlineVariant: Color(0xFFD5E2E1),
    inverseSurface: Color(0xFF0B3F45),
    onInverseSurface: Color(0xFFEAF6F5),
    inversePrimary: Color(0xFF7FD4CC),
    shadow: Color(0xFF0B3F45),
    scrim: Color(0xFF04181A),
    surfaceTint: Color(0x00000000),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF5ACFC5),
    onPrimary: Color(0xFF04292C),
    primaryContainer: Color(0xFF0E4F52),
    onPrimaryContainer: Color(0xFFBFE5E1),
    secondary: Color(0xFFBFE5E1),
    onSecondary: Color(0xFF0B3F45),
    secondaryContainer: Color(0xFF0F3F43),
    onSecondaryContainer: Color(0xFFCFEDEA),
    tertiary: Color(0xFFF0B458),
    onTertiary: Color(0xFF3F2704),
    tertiaryContainer: Color(0xFF4A3210),
    onTertiaryContainer: Color(0xFFFBE1B5),
    error: Color(0xFFFF8A8F),
    onError: Color(0xFF540B12),
    errorContainer: Color(0xFF5A1A20),
    onErrorContainer: Color(0xFFFFDADC),
    surface: Color(0xFF061A1C),
    onSurface: Color(0xFFE6F2F1),
    onSurfaceVariant: Color(0xFF9FB8BA),
    surfaceContainerLowest: Color(0xFF0C2427),
    surfaceContainerLow: Color(0xFF0C2427),
    surfaceContainer: Color(0xFF102C2F),
    surfaceContainerHigh: Color(0xFF163538),
    surfaceContainerHighest: Color(0xFF1C3F42),
    outline: Color(0xFF668285),
    outlineVariant: Color(0xFF234145),
    inverseSurface: Color(0xFFE6F2F1),
    onInverseSurface: Color(0xFF0B3F45),
    inversePrimary: Color(0xFF0F6E6E),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Color(0x00000000),
  );

  static ThemeData light() => _build(_lightScheme, _lightPalette);
  static ThemeData dark() => _build(_darkScheme, _darkPalette);

  /// Warning colour for statuses, matched to the current brightness.
  static Color warningFor(ColorScheme c) => c.brightness == Brightness.dark ? _darkPalette.warning : _lightPalette.warning;

  /// Success colour for statuses, matched to the current brightness.
  static Color successFor(ColorScheme c) => c.brightness == Brightness.dark ? _darkPalette.success : _lightPalette.success;

  /// The bundled fonts are licensed under the SIL Open Font License.
  static void registerFontLicenses() {
    LicenseRegistry.addLicense(() async* {
      for (final (package, file) in const [
        ('Plus Jakarta Sans', 'OFL-PlusJakartaSans.txt'),
        ('Bricolage Grotesque', 'OFL-BricolageGrotesque.txt'),
      ]) {
        yield LicenseEntryWithLineBreaks([package], await rootBundle.loadString('assets/fonts/$file'));
      }
    });
  }

  static TextTheme _text(TextTheme base) {
    TextStyle display(TextStyle? s, double size, FontWeight weight, double spacing) =>
        s!.copyWith(fontFamily: displayFont, fontSize: size, fontWeight: weight, letterSpacing: spacing, height: 1.12);
    return base.copyWith(
      displayLarge: display(base.displayLarge, 52, FontWeight.w800, -1.4),
      displayMedium: display(base.displayMedium, 42, FontWeight.w800, -1.1),
      displaySmall: display(base.displaySmall, 34, FontWeight.w800, -0.8),
      headlineLarge: display(base.headlineLarge, 30, FontWeight.w700, -0.6),
      headlineMedium: display(base.headlineMedium, 26, FontWeight.w700, -0.5),
      headlineSmall: display(base.headlineSmall, 23, FontWeight.w700, -0.3),
      titleLarge: display(base.titleLarge, 20, FontWeight.w700, -0.2),
      titleMedium: base.titleMedium!.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.1),
      titleSmall: base.titleSmall!.copyWith(fontWeight: FontWeight.w700),
      bodyLarge: base.bodyLarge!.copyWith(height: 1.45, letterSpacing: 0),
      bodyMedium: base.bodyMedium!.copyWith(height: 1.45, letterSpacing: 0),
      bodySmall: base.bodySmall!.copyWith(height: 1.35, letterSpacing: 0),
      labelLarge: base.labelLarge!.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.1),
      labelMedium: base.labelMedium!.copyWith(fontWeight: FontWeight.w600),
      labelSmall: base.labelSmall!.copyWith(fontWeight: FontWeight.w600),
    );
  }

  static ThemeData _build(ColorScheme c, AppPalette palette) {
    final dark = c.brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, colorScheme: c, fontFamily: bodyFont);
    final text = _text(base.textTheme);
    final card = BorderRadius.circular(20);
    final field = BorderRadius.circular(16);
    final button = BorderRadius.circular(16);
    final link = c.primary;

    // Buttons brighten on hover and deepen while pressed.
    WidgetStateProperty<Color?> overlay(Color on) => WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.pressed)) return on.withAlpha(46);
          if (s.contains(WidgetState.hovered)) return on.withAlpha(26);
          if (s.contains(WidgetState.focused)) return on.withAlpha(36);
          return null;
        });

    OutlineInputBorder border(Color color, [double width = 1]) => OutlineInputBorder(borderRadius: field, borderSide: BorderSide(color: color, width: width));

    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: c.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      hoverColor: c.onSurface.withAlpha(14),
      focusColor: c.primary.withAlpha(30),
      extensions: [palette],
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: LiftFadePageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: LiftFadePageTransitionsBuilder(),
        TargetPlatform.windows: LiftFadePageTransitionsBuilder(),
        TargetPlatform.linux: LiftFadePageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.onSurface,
        titleTextStyle: text.headlineSmall?.copyWith(color: c.onSurface),
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: card, side: BorderSide(color: c.outlineVariant)),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        iconColor: c.onSurfaceVariant,
        titleTextStyle: text.titleSmall?.copyWith(color: c.onSurface, fontWeight: FontWeight.w600),
        subtitleTextStyle: text.bodySmall?.copyWith(color: c.onSurfaceVariant),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surfaceContainerLowest,
        hoverColor: c.primaryContainer.withAlpha(dark ? 40 : 70),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        prefixIconColor: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.focused) ? link : c.onSurfaceVariant),
        suffixIconColor: c.onSurfaceVariant,
        labelStyle: TextStyle(color: c.onSurfaceVariant),
        floatingLabelStyle: TextStyle(color: link, fontWeight: FontWeight.w600),
        hintStyle: TextStyle(color: c.onSurfaceVariant.withAlpha(190)),
        border: border(c.outlineVariant),
        enabledBorder: border(c.outlineVariant),
        focusedBorder: border(link, 2),
        errorBorder: border(c.error),
        focusedErrorBorder: border(c.error, 2),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(54)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: button)),
          textStyle: WidgetStatePropertyAll(text.labelLarge?.copyWith(fontSize: 15)),
          overlayColor: overlay(c.onPrimary),
          animationDuration: const Duration(milliseconds: 180),
          shadowColor: WidgetStatePropertyAll(palette.shadow.withAlpha(110)),
          elevation: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled) || s.contains(WidgetState.pressed)) return 0;
            if (s.contains(WidgetState.hovered)) return 8;
            return 0;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size.fromHeight(50)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: button)),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          overlayColor: overlay(c.primary),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.onSurface.withAlpha(97) : c.onSurface),
          side: WidgetStateProperty.resolveWith((s) {
            if (s.contains(WidgetState.disabled)) return BorderSide(color: c.outlineVariant);
            if (s.contains(WidgetState.hovered) || s.contains(WidgetState.focused)) return BorderSide(color: c.primary, width: 1.5);
            return BorderSide(color: c.outline);
          }),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? c.onSurface.withAlpha(97) : link),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          overlayColor: overlay(link),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(overlayColor: overlay(c.onSurface)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceContainerLowest,
        selectedColor: c.primary,
        secondarySelectedColor: c.primary,
        disabledColor: c.surfaceContainerLow,
        checkmarkColor: c.onPrimary,
        side: WidgetStateBorderSide.resolveWith((s) {
          if (s.contains(WidgetState.selected)) return BorderSide(color: c.primary);
          if (s.contains(WidgetState.hovered)) return BorderSide(color: c.primary, width: 1.2);
          return BorderSide(color: c.outlineVariant);
        }),
        labelStyle: text.labelMedium?.copyWith(
          color: WidgetStateColor.resolveWith((s) => s.contains(WidgetState.selected)
              ? c.onPrimary
              : s.contains(WidgetState.disabled)
                  ? c.onSurface.withAlpha(97)
                  : c.onSurface),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 50)),
          textStyle: WidgetStatePropertyAll(text.labelMedium),
          backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceContainerLowest),
          foregroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.onSurface),
          iconColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.onSurfaceVariant),
          overlayColor: overlay(c.primary),
          side: WidgetStatePropertyAll(BorderSide(color: c.outlineVariant)),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: ShapeDecoration(
          color: c.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        labelColor: c.onPrimary,
        unselectedLabelColor: c.onSurfaceVariant,
        labelStyle: text.labelLarge,
        unselectedLabelStyle: text.labelLarge,
        splashBorderRadius: BorderRadius.circular(14),
        overlayColor: overlay(c.primary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.onPrimary : c.onSurfaceVariant),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? c.primary : c.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? Colors.transparent : c.outline),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: link,
        thumbColor: link,
        inactiveTrackColor: c.surfaceContainerHighest,
        overlayColor: link.withAlpha(36),
        trackHeight: 6,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: link, strokeCap: StrokeCap.round),
      dividerTheme: DividerThemeData(color: c.outlineVariant, thickness: 1, space: 1),
      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.headlineSmall?.copyWith(color: c.onSurface),
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onSurfaceVariant),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        elevation: 0,
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: c.outline,
        clipBehavior: Clip.antiAlias,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        backgroundColor: c.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.onInverseSurface, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: c.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.inverseSurface, borderRadius: BorderRadius.circular(10)),
        textStyle: text.labelSmall?.copyWith(color: c.onInverseSurface),
        waitDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}

/// Default route transition: the new page lifts and fades in while the old one
/// recedes slightly. iOS keeps its native swipe-back transition.
class LiftFadePageTransitionsBuilder extends PageTransitionsBuilder {
  const LiftFadePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) return child;
    final enter = CurvedAnimation(parent: animation, curve: const Cubic(0.2, 0, 0, 1), reverseCurve: Curves.easeInCubic);
    final recede = CurvedAnimation(parent: secondaryAnimation, curve: const Cubic(0.2, 0, 0, 1));
    return FadeTransition(
      opacity: Tween<double>(begin: 1, end: 0.55).animate(recede),
      child: ScaleTransition(
        scale: Tween<double>(begin: 1, end: 0.965).animate(recede),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.7, curve: Curves.easeOut)),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.045), end: Offset.zero).animate(enter),
            child: child,
          ),
        ),
      ),
    );
  }
}
