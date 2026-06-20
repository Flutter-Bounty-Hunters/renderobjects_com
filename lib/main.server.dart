library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'package:jaspr_content/components/callout.dart';
import 'package:jaspr_content/components/code_block.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import 'components/author_attribution_extension.dart';
import 'components/docs_layout_override.dart';
import 'components/embedded_thermostat.dart';
import 'components/hero_scene.dart';
import 'components/home_layout.dart';
import 'components/not_found_layout.dart';
import 'components/renderkit_layout.dart';
import 'components/renderkit_wizard_layout.dart';
import 'components/site_footer.dart';
import 'components/site_navbar.dart';

import 'main.server.options.dart';

// ─── Section definitions ───────────────────────────────────────────────────

const _guides = SidebarSection(
  title: 'Guides',
  dir: 'content/guides',
  urlPrefix: '/guides',
);

const _useCases = SidebarSection(
  title: 'Examples',
  dir: 'content/examples',
  urlPrefix: '/examples',
);

const _api = SidebarSection(
  title: 'API',
  dir: 'content/api',
  urlPrefix: '/api',
);

// ─── Main ──────────────────────────────────────────────────────────────────

// Lets images, videos, and audio live right next to the guide/API doc/example
// markdown files that reference them (e.g. `content/guides/diagram.png`
// referenced from `content/guides/layout.md` as `![diagram](./diagram.png)`),
// instead of requiring every asset to be flattened into `web/images/`.
final _contentAssets = AssetManager(directory: 'content');

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  ServerApp.addMiddleware(_contentAssets.middleware);

  runApp(
    ContentApp.custom(
      // Restrict the filesystem loader to markdown files only, so that
      // sibling assets (e.g. `nest-thermostat_paint.png`, referenced from
      // markdown via `_contentAssets`) aren't themselves treated as routable
      // pages — `jaspr build` eagerly builds every discovered route, and
      // would otherwise try (and fail) to parse binary files as page content.
      loaders: [FilesystemLoader('content', filterExtensions: {'.md'})],
      configResolver: PageConfig.all(
        dataLoaders: [FilesystemDataLoader('content/_data'), _contentAssets.dataLoader],
        templateEngine: MustacheTemplateEngine(),
        parsers: [MarkdownParser()],
        extensions: [
          HeadingAnchorsExtension(),
          TableOfContentsExtension(),
          AuthorAttributionExtension(),
          _contentAssets.pageExtension,
        ],
        components: [
          Callout(),
          CodeBlock(),
          CustomComponent(
            pattern: RegExp(r'EmbeddedThermostat'),
            builder: (name, attributes, child) => const EmbeddedThermostat(),
          ),
        ],
        layouts: [
          // Default: full sidebar, used by any page with no layout key (e.g. about).
          CustomDocsLayout(
            siteHeader: const SiteNavbar(),
            siteFooter: const SiteFooter(),
            sidebar: const DynamicSidebar(sections: [_guides, _useCases, _api]),
          ),
          // Section-specific layouts — matched by the `layout:` frontmatter key.
          // Every page in a section should declare `layout: guides` (etc.) so it
          // gets a sidebar scoped to that section only.
          CustomDocsLayout(
            layoutName: 'guides',
            siteHeader: const SiteNavbar(activePage: 'guides'),
            siteFooter: const SiteFooter(),
            sidebar: const DynamicSidebar(sections: [_guides]),
          ),
          CustomDocsLayout(
            layoutName: 'examples',
            siteHeader: const SiteNavbar(activePage: 'examples'),
            siteFooter: const SiteFooter(),
            sidebar: const DynamicSidebar(sections: [_useCases]),
          ),
          CustomDocsLayout(
            layoutName: 'api',
            siteHeader: const SiteNavbar(activePage: 'api'),
            siteFooter: const SiteFooter(),
            sidebar: const DynamicSidebar(sections: [_api]),
          ),
          // HomeLayout is matched by name for pages with `layout: home`.
          const HomeLayout(),
          // NotFoundLayout is matched by name for pages with `layout: notfound`.
          const NotFoundLayout(),
          // Layout names are matched as a prefix of the page's `layout:` key, so
          // the more specific 'renderkit-wizard' must be checked before the
          // shorter 'renderkit' (which would otherwise match it too).
          // RenderKitWizardLayout is matched by name for pages with `layout: renderkit-wizard`.
          const RenderKitWizardLayout(),
          // RenderKitLayout is matched by name for pages with `layout: renderkit`.
          const RenderKitLayout(),
        ],
        // All colors set as plain Color (not ThemeColor) so they apply to :root
        // unconditionally — the site never activates data-theme="dark", so light-mode
        // CSS variables are always the ones in use.
        theme: ContentTheme(
          primary: Color('#5b8dee'),
          background: Color('#0a0a0a'),
          text: Color('#999999'),
          colors: [
            ContentColors.headings.apply(Color('#ececec')),
            ContentColors.lead.apply(Color('#999999')),
            ContentColors.links.apply(Color('#82acf3')),
            ContentColors.bold.apply(Color('#ececec')),
            ContentColors.counters.apply(Color('#4a4a4a')),
            ContentColors.bullets.apply(Color('#4a4a4a')),
            ContentColors.hr.apply(Color('rgba(255,255,255,0.07)')),
            ContentColors.quotes.apply(Color('#707070')),
            ContentColors.quoteBorders.apply(Color('rgba(255,255,255,0.09)')),
            ContentColors.captions.apply(Color('#4a4a4a')),
            ContentColors.code.apply(Color('#82acf3')),
            ContentColors.preCode.apply(Color('#a1a1a1')),
            ContentColors.preBg.apply(Color('#111111')),
            ContentColors.thBorders.apply(Color('rgba(255,255,255,0.07)')),
            ContentColors.tdBorders.apply(Color('rgba(255,255,255,0.07)')),
          ],
        ),
      ),
    ),
  );
}

// Ensure HeroScene is compiled into the client bundle.
// ignore: unused_element
HeroScene? _ref;
