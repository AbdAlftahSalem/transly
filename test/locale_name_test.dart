import 'package:test/test.dart';
import 'package:transly/transly.dart';

void main() {
  test('localeFromFileName', () {
    expect(localeFromFileName('app_en')?.locale, 'en');
    expect(localeFromFileName('app_en_US')?.locale, 'en_US');
    expect(localeFromFileName('intl_pt_BR')?.locale, 'pt_BR');
    expect(localeFromFileName('messages_zh_Hant_TW')?.locale, 'zh_Hant_TW');
    expect(localeFromFileName('en-US')?.locale, 'en-US');
    expect(localeFromFileName('ar')?.locale, 'ar');
    expect(localeFromFileName('fil')?.locale, 'fil');
    expect(localeFromFileName('strings'), isNull);
    expect(localeFromFileName('app_en')?.start, 4);
  });

  test('normalizeLocale and languageOf', () {
    expect(normalizeLocale('en-us'), 'en_US');
    expect(normalizeLocale('zh_hant_tw'), 'zh_Hant_TW');
    expect(languageOf('pt_BR'), 'pt');
  });

  test('engineLanguage', () {
    expect(engineLanguage('en_US'), 'en');
    expect(engineLanguage('zh_Hans'), 'zh-CN');
    expect(engineLanguage('zh_TW'), 'zh-TW');
    expect(engineLanguage('he'), 'iw');
    expect(engineLanguage('ar'), 'ar');
  });

  test('KeyMatcher wildcards', () {
    final m = KeyMatcher(['app_name', 'debug_*', 'a?c']);
    expect(m.matches('app_name'), isTrue);
    expect(m.matches('debug_banner'), isTrue);
    expect(m.matches('abc'), isTrue);
    expect(m.matches('abbc'), isFalse);
    expect(m.matches('app'), isFalse);
  });
}
