import 'dart:io';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_content/components/sidebar.dart';
import 'package:jaspr_content/jaspr_content.dart';

import 'analytics.dart';
import 'favicon.dart';

// ─── DynamicSidebar ────────────────────────────────────────────────────────

/// Describes one section (group) in the sidebar.
class SidebarSection {
  const SidebarSection({
    required this.title,
    required this.dir,
    required this.urlPrefix,
    this.overviewText = 'Overview',
  });

  final String title;

  /// Filesystem directory to scan for `.md` files (relative to project root).
  final String dir;

  /// URL prefix for links in this section (e.g. `'/guides'`).
  final String urlPrefix;

  /// Label for the fixed "Overview" link that always appears first.
  final String overviewText;
}

/// A sidebar that scans [sections] directories on every render, so new content
/// files appear automatically without a server restart or rebuild.
class DynamicSidebar extends StatelessComponent {
  const DynamicSidebar({required this.sections});

  final List<SidebarSection> sections;

  @override
  Component build(BuildContext context) {
    return Sidebar(
      groups: [
        for (final s in sections) ..._groupsForSection(s),
      ],
    );
  }

  /// Returns one [SidebarGroup] for the section's top-level files, followed by
  /// one additional [SidebarGroup] per subdirectory (sorted by `order:` then
  /// alphabetically).  A `_index.md` inside a subdirectory can supply its
  /// `title:` and `order:` — if absent, the group title is derived from the
  /// folder name.
  static List<SidebarGroup> _groupsForSection(SidebarSection s) {
    final root = Directory(s.dir);
    if (!root.existsSync()) {
      return [SidebarGroup(title: s.title, links: [SidebarLink(text: s.overviewText, href: s.urlPrefix)])];
    }

    final topLinks = <({SidebarLink item, int? order})>[];
    final subGroupEntries = <({SidebarGroup item, int? order})>[];

    for (final entry in root.listSync()) {
      if (entry is File) {
        final name = entry.uri.pathSegments.last;
        // Skip private files and index files — they're not standalone pages.
        if (name.startsWith('_') || name == 'index.md') continue;
        if (!name.endsWith('.md')) continue;
        final slug = name.replaceFirst(RegExp(r'\.md$'), '');
        final meta = _parseFrontmatter(entry, slug);
        topLinks.add((item: SidebarLink(text: meta.title, href: '${s.urlPrefix}/$slug'), order: meta.order));
      } else if (entry is Directory) {
        final dirName = entry.uri.pathSegments.where((seg) => seg.isNotEmpty).last;
        final meta = _parseDirMeta(entry, dirName);
        final links = _linksFromDir(entry.path, '${s.urlPrefix}/$dirName');
        if (links.isEmpty) continue;
        subGroupEntries.add((item: SidebarGroup(title: meta.title, links: links), order: meta.order));
      }
    }

    _sortByOrder(topLinks, (sl) => sl.text);
    _sortByOrder(subGroupEntries, (group) => group.title ?? '');

    return [
      SidebarGroup(
        title: s.title,
        links: [
          SidebarLink(text: s.overviewText, href: s.urlPrefix),
          ...topLinks.map((e) => e.item),
        ],
      ),
      ...subGroupEntries.map((e) => e.item),
    ];
  }

  static List<SidebarLink> _linksFromDir(String dir, String urlPrefix) {
    final directory = Directory(dir);
    if (!directory.existsSync()) return [];

    final entries = directory
        .listSync()
        .whereType<File>()
        .where((f) {
          final name = f.uri.pathSegments.last;
          return name.endsWith('.md') && !name.startsWith('_') && name != 'index.md';
        })
        .map((f) {
          final slug = f.uri.pathSegments.last.replaceFirst(RegExp(r'\.md$'), '');
          final meta = _parseFrontmatter(f, slug);
          return (item: SidebarLink(text: meta.title, href: '$urlPrefix/$slug'), order: meta.order);
        })
        .toList();

    _sortByOrder(entries, (sl) => sl.text);
    return entries.map((e) => e.item).toList();
  }

  static void _sortByOrder<T>(List<({T item, int? order})> entries, String Function(T) label) {
    entries.sort((x, y) {
      final ox = x.order;
      final oy = y.order;
      if (ox != null && oy != null) return ox.compareTo(oy);
      if (ox != null) return -1;
      if (oy != null) return 1;
      return label(x.item).compareTo(label(y.item));
    });
  }

  /// Reads `_index.md` from [dir] for the group's `title:` and `order:`.
  /// Falls back to capitalising [name] when the file is absent.
  static ({String title, int? order}) _parseDirMeta(Directory dir, String name) {
    final indexFile = File('${dir.path}/_index.md');
    if (indexFile.existsSync()) return _parseFrontmatter(indexFile, name);
    return (title: _slugToTitle(name), order: null);
  }

  static ({String title, int? order}) _parseFrontmatter(File file, String slug) {
    String? title;
    int? order;
    try {
      var inFrontmatter = false;
      for (final line in file.readAsLinesSync()) {
        if (line.trim() == '---') {
          if (!inFrontmatter) {
            inFrontmatter = true;
            continue;
          } else {
            break;
          }
        }
        if (!inFrontmatter) continue;
        if (line.startsWith('title:')) {
          title = line.substring(6).trim();
        } else if (line.startsWith('order:')) {
          order = int.tryParse(line.substring(6).trim());
        }
        if (title != null && order != null) break;
      }
    } catch (_) {}

    return (title: title ?? _slugToTitle(slug), order: order);
  }

  static String _slugToTitle(String slug) => slug
      .split('-')
      .map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

// ─── CustomDocsLayout ──────────────────────────────────────────────────────

/// Extends [DocsLayout] to inject dark-theme fonts and CSS.
///
/// [layoutName] is matched against a page's `layout:` frontmatter key.
/// Defaults to `'docs'` (the standard fallback name).
class CustomDocsLayout extends DocsLayout {
  const CustomDocsLayout({
    super.sidebar,
    Component? siteHeader,
    Component? siteFooter,
    this.layoutName = 'docs',
  }) : super(header: siteHeader, footer: siteFooter);

  final String layoutName;

  @override
  String get name => layoutName;

  @override
  Iterable<Component> buildHead(Page page) sync* {
    yield* super.buildHead(page);
    yield* faviconHead();
    yield link(href: 'https://fonts.googleapis.com', rel: 'preconnect');
    yield link(
      href: 'https://fonts.gstatic.com',
      rel: 'preconnect',
      attributes: {'crossorigin': ''},
    );
    yield link(
      href: 'https://fonts.googleapis.com/css2?family=Inter:wght@400;450;500;600;700;800&family=JetBrains+Mono:wght@400;500&display=swap',
      rel: 'stylesheet',
    );
    yield link(href: '/styles.css', rel: 'stylesheet');
    yield link(href: '/docs.css', rel: 'stylesheet');
    yield script(src: '/search.js', defer: true);
    yield* analyticsHead();
  }
}
