import 'package:test/test.dart';
import 'package:transly/transly.dart';

void main() {
  group('parseIcu', () {
    test('plain text has no arguments', () {
      final m = parseIcu('Hello world');
      expect(m.error, isNull);
      expect(m.arguments, isEmpty);
      expect(renderMessage(m.nodes), 'Hello world');
    });

    test('simple placeholders', () {
      expect(parseIcu('Hi {name}, you have {count} messages').arguments, {'name': '', 'count': ''});
    });

    test('typed placeholders', () {
      expect(parseIcu('Total: {price, number, currency}').arguments, {'price': 'number'});
    });

    test('plural with nested placeholders', () {
      final m = parseIcu('{count, plural, =0{No items} one{1 item for {name}} other{{count} items for {name}}}');
      expect(m.error, isNull);
      expect(m.arguments, {'count': 'plural', 'name': ''});
      expect(m.choices.single.branches.map((b) => b.selector), ['=0', 'one', 'other']);
      expect(m.choices.single.hasOther, isTrue);
    });

    test('select nested in plural', () {
      final m = parseIcu(
          '{n, plural, one{{g, select, male{He} other{They}} has one} other{{g, select, male{He} other{They}} has {n}}}');
      expect(m.error, isNull);
      expect(m.arguments.keys, containsAll(['n', 'g']));
      expect(m.choices, hasLength(3));
    });

    test('easy_localization positional {}', () {
      final m = parseIcu('{} of {} done');
      expect(m.positionalCount, 2);
      expect(m.arguments, isEmpty);
    });

    test('render round-trips a plural', () {
      const s = '{count, plural, one{1 item} other{{count} items}}';
      expect(renderMessage(parseIcu(s).nodes), s);
    });

    test('unbalanced braces are errors', () {
      expect(parseIcu('Hello {name').error, contains('never closed'));
      expect(parseIcu('Hello name}').error, contains('unbalanced'));
      expect(parseIcu('{count, plural, one{x} other{y}').error, isNotNull);
    });

    test('missing other is visible', () {
      expect(parseIcu('{c, plural, one{x}}').choices.single.hasOther, isFalse);
    });

    test('braces around non-arguments stay text', () {
      final m = parseIcu('Price { 5 \$ } ok {x}');
      expect(m.error, isNull);
      expect(m.arguments.keys, ['x']);
    });
  });

  group('comparePlaceholders', () {
    List<String> cmp(String a, String b) => comparePlaceholders(parseIcu(a), parseIcu(b));

    test('same placeholders, any order', () {
      expect(cmp('{a} and {b}', '{b} et {a}'), isEmpty);
    });

    test('missing and unknown', () {
      expect(cmp('Hi {name}', 'Salut'), ['{name} is missing']);
      expect(cmp('Hi', 'Salut {name}'), ['{name} is not in the base text']);
    });

    test('plural turned into plain text', () {
      expect(cmp('{n, plural, one{1} other{{n}}}', '{n} items'), ['{n} is a plural in the base but plain here']);
    });

    test('positional count', () {
      expect(cmp('{} of {}', '{}'), ['1 positional {} here, 2 in the base']);
    });

    test('translation plural without other', () {
      expect(cmp('{n, plural, one{1} other{{n}}}', '{n, plural, one{1}}'), ['{n, plural} has no "other" case']);
    });

    test('different plural categories are fine (ar has more)', () {
      expect(cmp('{n, plural, one{1} other{{n}}}', '{n, plural, zero{0} one{1} two{2} few{{n}} many{{n}} other{{n}}}'),
          isEmpty);
    });
  });
}
