import 'package:flutter/material.dart';

import 'tokens.dart';

/// An organic rounded shape, as four fractions of the box: where the curves
/// meet on the top, bottom, start and end sides. Each side's two corners
/// always add up to the whole side, so the outline stays smooth.
@immutable
class PebbleShape {
  const PebbleShape(this.top, this.bottom, this.start, this.end);

  /// The same seed always gives the same shape, on every phone and version,
  /// so a person's pebble doesn't change between visits. dart:math's Random
  /// makes no such promise across versions.
  factory PebbleShape.fromSeed(int seed) {
    var state = (seed ^ 0x5DEECE66) & 0x7FFFFFFF;
    double next() {
      state = (state * 1103515245 + 12345) & 0x7FFFFFFF;
      // The high bits of this generator are the well-mixed ones.
      return _min + (state >> 8) % 1000 / 1000 * (_max - _min);
    }

    return PebbleShape(next(), next(), next(), next());
  }

  /// The range Variation B's pebbles stay in.
  static const _min = 0.38;
  static const _max = 0.62;

  /// Top side: the start corner's share of it.
  final double top;

  /// Bottom side: the start corner's share of it.
  final double bottom;

  /// Start side: the top corner's share of it.
  final double start;

  /// End side: the top corner's share of it.
  final double end;

  /// Elliptical corners for a box of [size]. Directional, so the shape
  /// mirrors with the layout.
  BorderRadiusDirectional radiiFor(Size size) {
    final w = size.width;
    final h = size.height;
    return BorderRadiusDirectional.only(
      topStart: Radius.elliptical(w * top, h * start),
      topEnd: Radius.elliptical(w * (1 - top), h * end),
      bottomStart: Radius.elliptical(w * bottom, h * (1 - start)),
      bottomEnd: Radius.elliptical(w * (1 - bottom), h * (1 - end)),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PebbleShape &&
      other.top == top &&
      other.bottom == bottom &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(top, bottom, start, end);
}

/// [PebbleShape] as a border, for anything that takes a [ShapeBorder].
class PebbleBorder extends ShapeBorder {
  const PebbleBorder(this.shape, {this.side = BorderSide.none});

  final PebbleShape shape;
  final BorderSide side;

  RRect _rrect(Rect rect, TextDirection? direction) => shape
      .radiiFor(rect.size)
      .resolve(direction ?? TextDirection.rtl)
      .toRRect(rect);

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.strokeInset);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect.deflate(side.strokeInset), textDirection));

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      Path()..addRRect(_rrect(rect, textDirection));

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style == BorderStyle.none) return;
    canvas.drawPath(
      getOuterPath(rect, textDirection: textDirection),
      side.toPaint(),
    );
  }

  @override
  ShapeBorder scale(double t) => PebbleBorder(shape, side: side.scale(t));

  @override
  bool operator ==(Object other) =>
      other is PebbleBorder && other.shape == shape && other.side == side;

  @override
  int get hashCode => Object.hash(shape, side);
}

/// A soft organic tile. With [onTap] it is a button, and must have a
/// [semanticLabel] or a text [child]; it is never smaller than a touch target.
class Pebble extends StatelessWidget {
  const Pebble({
    super.key,
    required this.seed,
    required this.color,
    this.width,
    this.height,
    this.child,
    this.onTap,
    this.semanticLabel,
    this.side = BorderSide.none,
    this.shadow = true,
  });

  final int seed;
  final Color color;
  final double? width;
  final double? height;
  final Widget? child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final BorderSide side;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final border = PebbleBorder(PebbleShape.fromSeed(seed), side: side);
    final content = Center(
      child: ExcludeSemantics(excluding: semanticLabel != null, child: child),
    );
    return Semantics(
      container: true,
      button: onTap != null,
      label: semanticLabel,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: onTap == null ? 0 : UsraSizes.touchTarget,
          minHeight: onTap == null ? 0 : UsraSizes.touchTarget,
        ),
        child: SizedBox(
          width: width,
          height: height,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: border,
              shadows: shadow ? context.usra.shadowCard : null,
            ),
            child: Material(
              color: color,
              shape: border,
              clipBehavior: Clip.antiAlias,
              child: onTap == null
                  ? content
                  : InkWell(onTap: onTap, customBorder: border, child: content),
            ),
          ),
        ),
      ),
    );
  }
}
