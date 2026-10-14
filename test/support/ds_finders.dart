import 'package:flutter_test/flutter_test.dart';
import 'package:anoya/core/ds.dart';

Finder findGlyph(Glyph glyph) =>
    find.byWidgetPredicate((w) => w is GlyphIcon && w.glyph == glyph);

Finder findRow(String title) =>
    find.byWidgetPredicate((w) => w is DsRow && w.title == title);
