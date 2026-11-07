import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:transly/transly.dart';

/// Translates by upper-casing letters and keeping tokens, and records calls.
class FakeEngine implements TranslationEngine {
  FakeEngine({this.name = 'fake', this.fail = const {}, this.breakTokens = const {}});

  @override
  final String name;
  final Set<String> fail;
  final Set<String> breakTokens;
  final calls = <List<String>>[];

  @override
  Future<List<String?>> translate(List<String> texts, {required String from, required String to}) async {
    calls.add(texts);
    return [
      for (final t in texts)
        if (fail.contains(t))
          null
        else if (breakTokens.contains(t))
          t.replaceAll(RegExp(r'\{\d+\}'), '')
        else
          '[$to] ${t.toUpperCase()}',
    ];
  }
}

void main() {
  group('translateMessages', () {
    test('placeholders are masked and restored', () async {
      final e = FakeEngine();
      final r = await translateMessages({'w': 'Welcome back, {name}!'}, engines: [e], from: 'en', to: 'ar');
      expect(e.calls.single, ['Welcome back, {0}!']);
      expect(r.translated['w'], '[ar] WELCOME BACK, {name}!');
      expect(r.engineByKey['w'], 'fake');
    });

    test('plural cases are translated one by one and the ICU rebuilt', () async {
      final e = FakeEngine();
      const msg = '{count, plural, =0{Your cart is empty} =1{1 item} other{{count} items in your cart}}';
      final r = await translateMessages({'c': msg}, engines: [e], from: 'en', to: 'fr');
      expect(e.calls.single, unorderedEquals(['Your cart is empty', '1 item', '{0} items in your cart']));
      final out = r.translated['c']!;
      expect(
          out, '{count, plural, =0{[fr] YOUR CART IS EMPTY} =1{[fr] 1 ITEM} other{[fr] {count} ITEMS IN YOUR CART}}');
      final parsed = parseIcu(out);
      expect(parsed.error, isNull);
      expect(comparePlaceholders(parseIcu(msg), parsed), isEmpty);
    });

    test('select inside text', () async {
      final r = await translateMessages({'g': 'Note: {gender, select, male{he said} other{they said}} hi'},
          engines: [FakeEngine()], from: 'en', to: 'de');
      expect(r.translated['g'], '[de] NOTE: {gender, select, male{[de] HE SAID} other{[de] THEY SAID}} HI');
    });

    test('positional {} and typed args survive', () async {
      final r = await translateMessages({'p': '{} of {} done, {price, number}'},
          engines: [FakeEngine()], from: 'en', to: 'es');
      expect(r.translated['p'], '[es] {} OF {} DONE, {price, number}');
    });

    test('texts without letters are not sent', () async {
      final e = FakeEngine();
      final r = await translateMessages({'a': '{count}', 'b': '42 %'}, engines: [e], from: 'en', to: 'ar');
      expect(e.calls, isEmpty);
      expect(r.translated, {'a': '{count}', 'b': '42 %'});
    });

    test('identical texts are sent once', () async {
      final e = FakeEngine();
      await translateMessages({'a': 'Save', 'b': 'Save'}, engines: [e], from: 'en', to: 'ar');
      expect(e.calls.single, ['Save']);
    });

    test('failures and lost tokens fall through to the next engine', () async {
      final first = FakeEngine(name: 'one', fail: {'Hello'}, breakTokens: {'Hi {0}'});
      final second = FakeEngine(name: 'two');
      final r = await translateMessages({'a': 'Hello', 'b': 'Hi {name}', 'c': 'Bye'},
          engines: [first, second], from: 'en', to: 'ar');
      expect(second.calls.single, unorderedEquals(['Hello', 'Hi {0}']));
      expect(r.engineByKey, {'a': 'two', 'b': 'two', 'c': 'one'});
      expect(r.translated['b'], '[ar] HI {name}');
    });

    test('nothing usable is a failure, not a broken value', () async {
      final r = await translateMessages({
        'a': 'Hello {x}'
      }, engines: [
        FakeEngine(breakTokens: {'Hello {0}'})
      ], from: 'en', to: 'ar');
      expect(r.translated, isEmpty);
      expect(r.failed.keys, ['a']);
    });

    test('broken ICU is not sent', () async {
      final r = await translateMessages({'a': 'Hello {x'}, engines: [FakeEngine()], from: 'en', to: 'ar');
      expect(r.failed['a'], startsWith('ICU syntax'));
    });

    test('outer spaces are kept', () async {
      final r = await translateMessages({'a': '{n, plural, one{ item} other{ items}}'},
          engines: [FakeEngine()], from: 'en', to: 'ar');
      expect(r.translated['a'], '{n, plural, one{ [ar] ITEM} other{ [ar] ITEMS}}');
    });
  });

  group('GoogleFreeEngine (fake HTTP)', () {
    test('batches texts in one POST and parses the reply', () async {
      final requests = <(String, Uri, String?)>[];
      Future<HttpReply> send(String method, Uri uri, {String? body, Map<String, String> headers = const {}}) async {
        requests.add((method, uri, body));
        return HttpReply(
            200,
            jsonEncode([
              'مرحبا',
              ['إعدادات', 'en']
            ]));
      }

      final out = await GoogleFreeEngine(send: send, pause: Duration.zero)
          .translate(['Hello', 'Settings'], from: 'en', to: 'ar');
      expect(out, ['مرحبا', 'إعدادات']);
      expect(requests.single.$1, 'POST');
      expect(requests.single.$2.queryParameters['tl'], 'ar');
      expect(requests.single.$3, 'q=Hello&q=Settings');
    });

    test('splits into batches', () async {
      var calls = 0;
      Future<HttpReply> send(String m, Uri u, {String? body, Map<String, String> headers = const {}}) async {
        calls++;
        final n = body!.split('&').length;
        return HttpReply(200, jsonEncode(List.filled(n, 'x')));
      }

      final out = await GoogleFreeEngine(send: send, batchSize: 2, pause: Duration.zero)
          .translate(['a', 'b', 'c', 'd', 'e'], from: 'en', to: 'de');
      expect(calls, 3);
      expect(out, everyElement('x'));
    });

    test('retries on 429 then succeeds', () async {
      var calls = 0;
      Future<HttpReply> send(String m, Uri u, {String? body, Map<String, String> headers = const {}}) async {
        calls++;
        return calls < 3 ? const HttpReply(429, 'slow down') : HttpReply(200, jsonEncode(['ok']));
      }

      final out = await GoogleFreeEngine(send: send, pause: Duration.zero, backoff: Duration.zero)
          .translate(['a'], from: 'en', to: 'de');
      expect(calls, 3);
      expect(out, ['ok']);
    });

    test('a blocked endpoint gives nulls, not an exception', () async {
      Future<HttpReply> send(String m, Uri u, {String? body, Map<String, String> headers = const {}}) async =>
          const HttpReply(403, '<html>');
      expect(await GoogleFreeEngine(send: send, pause: Duration.zero).translate(['a'], from: 'en', to: 'de'), [null]);
    });
  });

  group('MyMemoryEngine (fake HTTP)', () {
    test('one GET per text, langpair and email', () async {
      final uris = <Uri>[];
      Future<HttpReply> send(String m, Uri u, {String? body, Map<String, String> headers = const {}}) async {
        uris.add(u);
        return HttpReply(
            200,
            jsonEncode({
              'responseStatus': 200,
              'responseData': {'translatedText': 'It&#39;s ${u.queryParameters['q']}'}
            }));
      }

      final out = await MyMemoryEngine(send: send, email: 'me@example.com', pause: Duration.zero)
          .translate(['a', 'b'], from: 'ar', to: 'en');
      expect(out, ["It's a", "It's b"]);
      expect(uris.first.queryParameters['langpair'], 'ar|en');
      expect(uris.first.queryParameters['de'], 'me@example.com');
    });

    test('quota warnings are failures', () async {
      Future<HttpReply> send(String m, Uri u, {String? body, Map<String, String> headers = const {}}) async =>
          HttpReply(
              200,
              jsonEncode({
                'responseStatus': 200,
                'responseData': {'translatedText': 'MYMEMORY WARNING: YOU USED ALL AVAILABLE FREE TRANSLATIONS'}
              }));
      expect(await MyMemoryEngine(send: send, pause: Duration.zero).translate(['a'], from: 'en', to: 'de'), [null]);
    });
  });

  test('enginesFor', () {
    expect(enginesFor('auto').map((e) => e.name), ['google', 'mymemory']);
    expect(enginesFor('google').map((e) => e.name), ['google']);
    expect(enginesFor('mymemory').map((e) => e.name), ['mymemory']);
  });

  group('live (free endpoints)', () {
    final live = Platform.environment['TRANSLY_LIVE'] == '1';

    test('en → ar and ar → en keep placeholders and plurals', () async {
      const en = {
        'welcome': 'Welcome back, {name}!',
        'items': '{count, plural, =0{Your cart is empty} =1{One item in your cart} other{{count} items in your cart}}',
      };
      final ar = await translateMessages(en, engines: enginesFor('auto'), from: 'en', to: 'ar');
      expect(ar.failed, isEmpty);
      for (final k in en.keys) {
        expect(comparePlaceholders(parseIcu(en[k]!), parseIcu(ar.translated[k]!)), isEmpty, reason: ar.translated[k]);
        expect(ar.translated[k], matches(RegExp(r'[\u0600-\u06FF]')));
      }
      final back =
          await translateMessages({'w': ar.translated['welcome']!}, engines: enginesFor('auto'), from: 'ar', to: 'en');
      expect(back.translated['w'], contains('{name}'));
      expect(back.translated['w'], matches(RegExp('[A-Za-z]')));
    },
        skip: live ? false : 'set TRANSLY_LIVE=1 to call the free endpoints',
        timeout: const Timeout(Duration(minutes: 2)));
  });
}
