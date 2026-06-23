class RootMetaTag {
  const RootMetaTag({required this.name, required this.content});

  final String name;
  final String content;
}

class RootLinkTag {
  const RootLinkTag({
    required this.rel,
    required this.href,
    this.type,
    this.sizes,
  });

  final String rel;
  final String href;
  final String? type;
  final String? sizes;
}

class RootLayoutContract {
  const RootLayoutContract({
    required this.title,
    required this.description,
    required this.cacheVersion,
    required this.safeTechnicalCacheKeys,
    required this.legacyKeysToRemove,
    required this.meta,
    required this.links,
  });

  final String title;
  final String description;
  final String cacheVersion;
  final List<String> safeTechnicalCacheKeys;
  final List<String> legacyKeysToRemove;
  final List<RootMetaTag> meta;
  final List<RootLinkTag> links;
}

const rootLayoutContract = RootLayoutContract(
  title: 'SIM AI Tutor — Seu tutor de IA pessoal',
  description: 'SIM AI Tutor: tutor de Inteligência Artificial com Gemini 2.5 Flash.',
  cacheVersion: 'sim-core-stable-2026-06-08-01',
  safeTechnicalCacheKeys: ['sim-credits-cache-v0'],
  legacyKeysToRemove: ['sim-state-v0', 'cyber-reviews-v0'],
  meta: [
    RootMetaTag(name: 'viewport', content: 'width=device-width, initial-scale=1'),
    RootMetaTag(name: 'author', content: 'SIM AI Tutor'),
    RootMetaTag(name: 'theme-color', content: '#ffffff'),
    RootMetaTag(name: 'og:site_name', content: 'SIM — Smart Intelligence Mentor'),
    RootMetaTag(name: 'og:type', content: 'website'),
    RootMetaTag(name: 'twitter:card', content: 'summary_large_image'),
    RootMetaTag(name: 'twitter:site', content: '@Lovable'),
  ],
  links: [
    RootLinkTag(rel: 'manifest', href: '/manifest.json'),
    RootLinkTag(rel: 'icon', type: 'image/png', sizes: '192x192', href: '/icon-192x192.png'),
    RootLinkTag(rel: 'icon', type: 'image/png', sizes: '512x512', href: '/icon-512x512.png'),
    RootLinkTag(rel: 'apple-touch-icon', href: '/icon-192x192.png'),
  ],
);

abstract interface class TechnicalCacheStorage {
  String? read(String key);
  void write(String key, String value);
  void remove(String key);
}

class MemoryTechnicalCacheStorage implements TechnicalCacheStorage {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  void remove(String key) {
    values.remove(key);
  }

  @override
  void write(String key, String value) {
    values[key] = value;
  }
}

class TechnicalCacheMigration {
  TechnicalCacheMigration({
    required this.storage,
    this.contract = rootLayoutContract,
  });

  static const versionKey = 'sim-technical-cache-version';

  final TechnicalCacheStorage storage;
  final RootLayoutContract contract;

  void run() {
    for (final key in contract.legacyKeysToRemove) {
      storage.remove(key);
    }
    final current = storage.read(versionKey);
    if (current == contract.cacheVersion) return;
    for (final key in contract.safeTechnicalCacheKeys) {
      storage.remove(key);
    }
    storage.write(versionKey, contract.cacheVersion);
  }
}

class RootLifecycleHooks {
  const RootLifecycleHooks({
    required this.wireCloudQueueLifecycle,
    required this.pullCloudLessons,
    required this.invalidateRouter,
    required this.invalidateQueries,
  });

  final void Function() wireCloudQueueLifecycle;
  final void Function() pullCloudLessons;
  final void Function() invalidateRouter;
  final void Function() invalidateQueries;
}
