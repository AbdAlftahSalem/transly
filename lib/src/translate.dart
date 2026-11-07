/// Free machine translation that keeps placeholders and ICU syntax intact.
///
/// No API key is needed. Two free endpoints are used: Google Translate's
/// public web endpoint first, then MyMemory as a fallback for anything the
/// first one could not translate. Every placeholder (`{name}`, `{}`) is
/// replaced by a numbered token before sending and put back after; plural
/// and select cases are translated one by one and the ICU structure is
/// rebuilt around them, so keys, argument names and selectors never change.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'icu.dart';
import 'locale_name.dart';

/// A plain HTTP reply.
class HttpReply {
  /// Creates a reply.
  const HttpReply(this.status, this.body);

  /// The status code.
  final int status;

  /// The body, decoded as UTF-8.
  final String body;
}

/// Sends one HTTP request. Swappable for tests.
typedef HttpSend = Future<HttpReply> Function(String method, Uri uri, {String? body, Map<String, String> headers});

/// The default [HttpSend], built on `dart:io`.
Future<HttpReply> ioHttpSend(String method, Uri uri, {String? body, Map<String, String> headers = const {}}) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final req = await client.openUrl(method, uri).timeout(const Duration(seconds: 20));
    req.headers.set(HttpHeaders.userAgentHeader, 'Mozilla/5.0 (transly; +https://pub.dev/packages/transly)');
    headers.forEach(req.headers.set);
    if (body != null) req.add(utf8.encode(body));
    final res = await req.close().timeout(const Duration(seconds: 30));
    final text = await res.transform(utf8.decoder).join().timeout(const Duration(seconds: 30));
    return HttpReply(res.statusCode, text);
  } finally {
    client.close(force: true);
  }
}

/// Something that translates a batch of plain texts.
abstract class TranslationEngine {
  /// The engine name shown in reports (`google`, `mymemory`).
  String get name;

  /// Translates [texts] from [from] to [to] (engine language codes).
  /// Returns one result per text, null where that text failed.
  Future<List<String?>> translate(List<String> texts, {required String from, required String to});
}

/// Retries [call] on errors and on 429/5xx replies, waiting longer each time.
Future<HttpReply> _withRetry(Future<HttpReply> Function() call,
    {int attempts = 3, Duration backoff = const Duration(seconds: 1)}) async {
  Object? lastError;
  for (var i = 0; i < attempts; i++) {
    try {
      final r = await call();
      if (r.status == 429 || r.status >= 500) {
        lastError = 'HTTP ${r.status}';
      } else {
        return r;
      }
    } on Object catch (e) {
      lastError = e;
    }
    if (i < attempts - 1) await Future<void>.delayed(backoff * (1 << i));
  }
  throw HttpException('request failed after $attempts attempts: $lastError');
}

/// Google Translate's free web endpoint (no key). Batches many texts in one
/// request.
class GoogleFreeEngine implements TranslationEngine {
  /// Creates the engine.
  GoogleFreeEngine(
      {HttpSend? send,
      this.batchSize = 40,
      this.maxChars = 4000,
      this.pause = const Duration(milliseconds: 300),
      this.backoff = const Duration(seconds: 1)})
      : _send = send ?? ioHttpSend;

  final HttpSend _send;

  /// Texts per request.
  final int batchSize;

  /// Characters per request.
  final int maxChars;

  /// Wait between requests (rate limit).
  final Duration pause;

  /// First retry wait.
  final Duration backoff;

  @override
  String get name => 'google';

  @override
  Future<List<String?>> translate(List<String> texts, {required String from, required String to}) async {
    final out = List<String?>.filled(texts.length, null);
    var i = 0;
    var first = true;
    while (i < texts.length) {
      final batch = <int>[];
      var chars = 0;
      while (i < texts.length && batch.length < batchSize && (batch.isEmpty || chars + texts[i].length <= maxChars)) {
        batch.add(i);
        chars += texts[i].length;
        i++;
      }
      if (!first) await Future<void>.delayed(pause);
      first = false;
      try {
        final uri =
            Uri.https('clients5.google.com', '/translate_a/t', {'client': 'dict-chrome-ex', 'sl': from, 'tl': to});
        final body = batch.map((k) => 'q=${Uri.encodeQueryComponent(texts[k])}').join('&');
        final reply = await _withRetry(
          () => _send('POST', uri,
              body: body, headers: {'content-type': 'application/x-www-form-urlencoded; charset=UTF-8'}),
          backoff: backoff,
        );
        if (reply.status != 200) continue;
        final decoded = jsonDecode(reply.body);
        if (decoded is! List || decoded.length != batch.length) continue;
        for (var k = 0; k < batch.length; k++) {
          final item = decoded[k];
          final text = item is String
              ? item
              : (item is List && item.isNotEmpty && item.first is String ? item.first as String : null);
          if (text != null && text.trim().isNotEmpty) out[batch[k]] = text;
        }
      } on Object {
        // Leave this batch as failed; the fallback engine gets it.
      }
    }
    return out;
  }
}

/// MyMemory's free API (no key; about 5,000 characters a day per IP, or
/// 50,000 with an email). One text per request.
class MyMemoryEngine implements TranslationEngine {
  /// Creates the engine. [email] raises MyMemory's free daily limit.
  MyMemoryEngine(
      {HttpSend? send,
      this.email,
      this.pause = const Duration(milliseconds: 500),
      this.backoff = const Duration(seconds: 1)})
      : _send = send ?? ioHttpSend;

  final HttpSend _send;

  /// Optional contact email sent as `de=` (raises the daily limit).
  final String? email;

  /// Wait between requests (rate limit).
  final Duration pause;

  /// First retry wait.
  final Duration backoff;

  @override
  String get name => 'mymemory';

  @override
  Future<List<String?>> translate(List<String> texts, {required String from, required String to}) async {
    final out = List<String?>.filled(texts.length, null);
    for (var k = 0; k < texts.length; k++) {
      if (k > 0) await Future<void>.delayed(pause);
      if (utf8.encode(texts[k]).length > 500) continue;
      try {
        final uri = Uri.https('api.mymemory.translated.net', '/get', {
          'q': texts[k],
          'langpair': '$from|$to',
          if (email != null) 'de': email!,
        });
        final reply = await _withRetry(() => _send('GET', uri), backoff: backoff);
        if (reply.status != 200) continue;
        final data = jsonDecode(reply.body);
        if (data is! Map) continue;
        if ('${data['responseStatus']}' != '200' || data['quotaFinished'] == true) {
          if ('${data['responseStatus']}' == '429' || data['quotaFinished'] == true) break;
          continue;
        }
        final text = (data['responseData'] as Map?)?['translatedText'];
        if (text is String &&
            text.trim().isNotEmpty &&
            !text.contains('MYMEMORY WARNING') &&
            !text.contains('QUERY LENGTH LIMIT')) {
          out[k] = _unescapeHtml(text);
        }
      } on Object {
        // Failed; reported as untranslated.
      }
    }
    return out;
  }
}

String _unescapeHtml(String s) => s
    .replaceAll('&#39;', "'")
    .replaceAll('&quot;', '"')
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');

/// The engines for `--engine` (`auto`, `google`, `mymemory`).
List<TranslationEngine> enginesFor(String name, {HttpSend? send, String? email}) => switch (name) {
      'google' => [GoogleFreeEngine(send: send)],
      'mymemory' => [MyMemoryEngine(send: send, email: email)],
      _ => [GoogleFreeEngine(send: send), MyMemoryEngine(send: send, email: email)],
    };

/// The language code the free engines expect for a Flutter locale:
/// `en_US` → `en`, `zh_Hans`/`zh_CN` → `zh-CN`, `zh_Hant`/`zh_TW` → `zh-TW`,
/// `pt_BR` → `pt`, `he` → `iw`, `fil` → `tl`.
String engineLanguage(String locale) {
  final n = normalizeLocale(locale);
  final lang = languageOf(n);
  if (lang == 'zh') {
    return (n.contains('Hant') || n.endsWith('_TW') || n.endsWith('_HK') || n.endsWith('_MO')) ? 'zh-TW' : 'zh-CN';
  }
  return switch (lang) { 'he' => 'iw', 'fil' => 'tl', 'nb' || 'nn' => 'no', _ => lang };
}

/// The outcome of [translateMessages].
class TranslationResult {
  /// Creates a result.
  const TranslationResult(this.translated, this.failed, this.engineByKey);

  /// Key → translated message, with placeholders and ICU syntax rebuilt.
  final Map<String, String> translated;

  /// Key → why it could not be translated.
  final Map<String, String> failed;

  /// Key → the engine that produced its text (`google`, `mymemory`, `-`).
  final Map<String, String> engineByKey;
}

/// Translates ICU [messages] (key → base text) from [from] to [to] locales.
///
/// Engines are tried in order; a text that fails, or comes back with a
/// placeholder token lost or changed, goes to the next engine.
Future<TranslationResult> translateMessages(
  Map<String, String> messages, {
  required List<TranslationEngine> engines,
  required String from,
  required String to,
  void Function(int done, int total)? onProgress,
}) async {
  final preps = <String, _Prep>{};
  final failed = <String, String>{};
  for (final e in messages.entries) {
    final msg = parseIcu(e.value);
    if (msg.error != null) {
      failed[e.key] = 'ICU syntax: ${msg.error}';
      continue;
    }
    preps[e.key] = _prepare(msg.nodes);
  }
  final jobs = <String>{};
  for (final prep in preps.values) {
    prep.collect(jobs);
  }
  final results = <String, String>{};
  final engineOf = <String, String>{};
  var pending = jobs.toList();
  final total = pending.length;
  final sl = engineLanguage(from);
  final tl = engineLanguage(to);
  for (final engine in engines) {
    if (pending.isEmpty) break;
    final trimmed = pending.map((t) => t.trim()).toList();
    final out = await engine.translate(trimmed, from: sl, to: tl);
    final still = <String>[];
    for (var i = 0; i < pending.length; i++) {
      final job = pending[i];
      final got = out[i];
      final fixed = got == null ? null : _restoreTokens(job, got);
      if (fixed == null) {
        still.add(job);
      } else {
        results[job] = _keepOuterSpace(job, fixed);
        engineOf[job] = engine.name;
      }
    }
    pending = still;
    onProgress?.call(total - pending.length, total);
  }
  final translated = <String, String>{};
  final engineByKey = <String, String>{};
  for (final e in preps.entries) {
    final text = e.value.assemble(results);
    if (text == null) {
      failed[e.key] = 'no engine returned a usable translation';
    } else {
      translated[e.key] = text;
      final used = <String>{};
      e.value.engines(engineOf, used);
      engineByKey[e.key] = used.isEmpty ? '-' : used.join('+');
    }
  }
  return TranslationResult(translated, failed, engineByKey);
}

final RegExp _token = RegExp(r'\{\s*(\d+)\s*\}');
final RegExp _anyLetter = RegExp(r'\p{L}', unicode: true);

bool _needsTranslation(String masked) => _anyLetter.hasMatch(masked.replaceAll(_token, ''));

/// Checks that [got] has exactly the tokens of [job]; returns it normalized.
String? _restoreTokens(String job, String got) {
  final want = _token.allMatches(job).map((m) => m.group(1)).toList()..sort();
  final have = _token.allMatches(got).map((m) => m.group(1)).toList()..sort();
  if (want.join(',') != have.join(',')) return null;
  if (got.contains('{') && got.replaceAll(_token, '').contains(RegExp(r'[{}]'))) return null;
  return got.replaceAllMapped(_token, (m) => '{${m.group(1)}}');
}

String _keepOuterSpace(String original, String translated) {
  final lead = RegExp(r'^\s*').firstMatch(original)!.group(0)!;
  final trail = RegExp(r'\s*$').firstMatch(original)!.group(0)!;
  return '$lead${translated.trim()}$trail';
}

sealed class _Slot {}

class _RawSlot extends _Slot {
  _RawSlot(this.raw);
  final String raw;
}

class _ChoiceSlot extends _Slot {
  _ChoiceSlot(this.choice, this.branches);
  final IcuChoice choice;
  final List<_Prep> branches;
}

class _Prep {
  _Prep(this.masked, this.slots);
  final String masked;
  final List<_Slot> slots;

  void collect(Set<String> jobs) {
    if (_needsTranslation(masked)) jobs.add(masked);
    for (final s in slots) {
      if (s is _ChoiceSlot) {
        for (final b in s.branches) {
          b.collect(jobs);
        }
      }
    }
  }

  void engines(Map<String, String> engineOf, Set<String> used) {
    final e = engineOf[masked];
    if (e != null) used.add(e);
    for (final s in slots) {
      if (s is _ChoiceSlot) {
        for (final b in s.branches) {
          b.engines(engineOf, used);
        }
      }
    }
  }

  String? assemble(Map<String, String> results) {
    final text = _needsTranslation(masked) ? results[masked] : masked;
    if (text == null) return null;
    final rendered = <int, String>{};
    for (var i = 0; i < slots.length; i++) {
      final s = slots[i];
      if (s is _RawSlot) {
        rendered[i] = s.raw;
      } else if (s is _ChoiceSlot) {
        final b = StringBuffer('{${s.choice.name}, ${s.choice.type},');
        for (var k = 0; k < s.branches.length; k++) {
          final inner = s.branches[k].assemble(results);
          if (inner == null) return null;
          b.write(' ${s.choice.branches[k].selector}{$inner}');
        }
        b.write('}');
        rendered[i] = b.toString();
      }
    }
    return text.replaceAllMapped(_token, (m) => rendered[int.parse(m.group(1)!)] ?? m.group(0)!);
  }
}

_Prep _prepare(List<IcuNode> nodes) {
  final b = StringBuffer();
  final slots = <_Slot>[];
  for (final n in nodes) {
    if (n is IcuText) {
      b.write(n.text);
    } else if (n is IcuArgument) {
      b.write('{${slots.length}}');
      slots.add(_RawSlot(n.raw));
    } else if (n is IcuChoice) {
      b.write('{${slots.length}}');
      slots.add(_ChoiceSlot(n, [for (final br in n.branches) _prepare(br.message)]));
    }
  }
  return _Prep(b.toString(), slots);
}
