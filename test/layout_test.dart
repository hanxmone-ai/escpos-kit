import 'package:escpos_kit/escpos_kit.dart';
import 'package:escpos_kit/src/layout.dart' show pad, runeWidth;
import 'package:test/test.dart';

void main() {
  group('width', () {
    test('Latin is one column, Chinese and full-width are two', () {
      expect(runeWidth('a'.runes.single), 1);
      expect(runeWidth('é'.runes.single), 1);
      expect(runeWidth('中'.runes.single), 2);
      expect(runeWidth('，'.runes.single), 2);
      expect(runeWidth('한'.runes.single), 2);
    });
    test('text width adds up', () => expect(textWidth('Flat white 中'), 13));
  });

  group('wrapText', () {
    test('breaks at spaces', () {
      expect(wrapText('the quick brown fox', 10), ['the quick', 'brown fox']);
    });
    test('breaks long words anywhere', () {
      expect(wrapText('abcdefghij', 4), ['abcd', 'efgh', 'ij']);
    });
    test('breaks Chinese by width', () {
      expect(wrapText('中文测试', 5), ['中文', '测试']);
      expect(wrapText('中文测试', 4), ['中文', '测试']);
    });
    test('keeps line breaks', () => expect(wrapText('a\nb', 5), ['a', 'b']));
    test('empty text is one empty line', () => expect(wrapText('', 5), ['']));
    test('text that fits is unchanged', () {
      expect(wrapText('Flat white', 32), ['Flat white']);
    });
    test('rejects zero width', () {
      expect(() => wrapText('a', 0), throwsRangeError);
    });
  });

  group('pad', () {
    test('left, right and center', () {
      expect(pad('ab', 5, PosAlign.left), 'ab   ');
      expect(pad('ab', 5, PosAlign.right), '   ab');
      expect(pad('ab', 5, PosAlign.center), ' ab  ');
    });
    test('counts Chinese as two columns', () {
      expect(pad('中', 4, PosAlign.right), '  中');
    });
  });

  group('autoWidths', () {
    test('item and price', () {
      expect(autoWidths(['Flat white', '4.50'], 32), [27, 4]);
    });
    test('three columns', () {
      expect(autoWidths(['Item', '2', '9.00'], 32), [25, 1, 4]);
    });
    test('one column takes the whole line', () {
      expect(autoWidths(['Hello'], 32), [32]);
    });
    test('falls back to even columns when the others are wide', () {
      expect(autoWidths(['x', 'a' * 40], 32), [16, 15]);
    });
  });

  group('layoutRow', () {
    test('item on the left, price on the right', () {
      final lines = layoutRow(['Flat white', '4.50'], [27, 4]);
      expect(lines, ['Flat white${' ' * 18}4.50']);
      expect(lines.single.length, 32);
    });
    test('long names wrap inside their column', () {
      final lines = layoutRow(['Banana bread with walnuts', '3.20'], [12, 4]);
      expect(lines, ['Banana bread 3.20', 'with walnuts']);
    });
    test('Chinese names line up', () {
      final lines = layoutRow(['拿铁', '28.00'], [10, 5]);
      expect(lines, ['拿铁${' ' * 7}28.00']);
      expect(textWidth(lines.single), 16);
    });
    test('custom alignment', () {
      final lines = layoutRow(
        ['a', 'b'],
        [3, 3],
        aligns: [PosAlign.center, PosAlign.left],
      );
      expect(lines, [' a  b']);
    });
    test('rejects mismatched lengths', () {
      expect(() => layoutRow(['a'], [1, 2]), throwsArgumentError);
    });
  });
}
