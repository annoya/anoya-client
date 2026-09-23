library;

import '../l10n/l10n.dart';

enum ServiceGroup {
  streaming,
  messengers,
  social,
  other;

  String get header => switch (this) {
    ServiceGroup.streaming => L10n.current.catalogGroupStreaming,
    ServiceGroup.messengers => L10n.current.catalogGroupMessengers,
    ServiceGroup.social => L10n.current.catalogGroupSocial,
    ServiceGroup.other => L10n.current.catalogGroupOther,
  };
}

class CatalogService {
  const CatalogService(
    this.name,
    this.category,
    this.group, {
    this.glyph = true,
  });

  final String name;

  final String category;

  final ServiceGroup group;

  final bool glyph;

  String get glyphAsset =>
      'assets/brands/${_slugOverrides[category] ?? category}.svg';

  static const _slugOverrides = {'twitter': 'x'};
}

const kServiceCatalog = [
  CatalogService('YouTube', 'youtube', ServiceGroup.streaming),
  CatalogService('Netflix', 'netflix', ServiceGroup.streaming),
  CatalogService('Twitch', 'twitch', ServiceGroup.streaming),
  CatalogService('Disney+', 'disney', ServiceGroup.streaming, glyph: false),
  CatalogService('HBO Max', 'hbo', ServiceGroup.streaming),
  CatalogService('Hulu', 'hulu', ServiceGroup.streaming),
  CatalogService('Prime Video', 'primevideo', ServiceGroup.streaming),
  CatalogService('Spotify', 'spotify', ServiceGroup.streaming),
  CatalogService('SoundCloud', 'soundcloud', ServiceGroup.streaming),
  CatalogService('TikTok', 'tiktok', ServiceGroup.streaming),
  CatalogService('Vimeo', 'vimeo', ServiceGroup.streaming),
  CatalogService('Telegram', 'telegram', ServiceGroup.messengers),
  CatalogService('WhatsApp', 'whatsapp', ServiceGroup.messengers),
  CatalogService('Signal', 'signal', ServiceGroup.messengers),
  CatalogService('Discord', 'discord', ServiceGroup.messengers),
  CatalogService('Viber', 'viber', ServiceGroup.messengers),
  CatalogService('Skype', 'skype', ServiceGroup.messengers),
  CatalogService('Slack', 'slack', ServiceGroup.messengers),
  CatalogService('Zoom', 'zoom', ServiceGroup.messengers),
  CatalogService('LINE', 'line', ServiceGroup.messengers),
  CatalogService('Instagram', 'instagram', ServiceGroup.social),
  CatalogService('Facebook', 'facebook', ServiceGroup.social),
  CatalogService('X (Twitter)', 'twitter', ServiceGroup.social),
  CatalogService('Reddit', 'reddit', ServiceGroup.social),
  CatalogService('VK', 'vk', ServiceGroup.social),
  CatalogService('LinkedIn', 'linkedin', ServiceGroup.social),
  CatalogService('Pinterest', 'pinterest', ServiceGroup.social),
  CatalogService('Snapchat', 'snapchat', ServiceGroup.social),
  CatalogService('Tumblr', 'tumblr', ServiceGroup.social),
  CatalogService('Google', 'google', ServiceGroup.other),
  CatalogService('ChatGPT', 'openai', ServiceGroup.other),
  CatalogService('GitHub', 'github', ServiceGroup.other),
  CatalogService('Wikipedia', 'wikipedia', ServiceGroup.other),
  CatalogService('Steam', 'steam', ServiceGroup.other),
];

CatalogService? catalogServiceFor(String category) {
  for (final s in kServiceCatalog) {
    if (s.category == category) return s;
  }
  return null;
}
