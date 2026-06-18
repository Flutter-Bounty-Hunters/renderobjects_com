library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';

import 'package:jaspr_content/components/callout.dart';
import 'package:jaspr_content/components/code_block.dart';
import 'package:jaspr_content/jaspr_content.dart';
import 'package:jaspr_content/theme.dart';

import 'components/docs_layout_override.dart';
import 'components/hero_scene.dart';
import 'components/home_layout.dart';
import 'components/render_studio_layout.dart';
import 'components/site_navbar.dart';

import 'main.server.options.dart';

// ─── Section definitions ───────────────────────────────────────────────────

const _guides = SidebarSection(
  title: 'Guides',
  dir: 'content/guides',
  urlPrefix: '/guides',
);

const _useCases = SidebarSection(
  title: 'Use Cases',
  dir: 'content/use-cases',
  urlPrefix: '/use-cases',
);

const _api = SidebarSection(
  title: 'API',
  dir: 'content/api',
  urlPrefix: '/api',
);

// ─── Main ──────────────────────────────────────────────────────────────────

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);

  runApp(
    ContentApp(
      templateEngine: MustacheTemplateEngine(),
      parsers: [MarkdownParser()],
      extensions: [
        HeadingAnchorsExtension(),
        TableOfContentsExtension(),
      ],
      components: [
        Callout(),
        CodeBlock(),
      ],
      layouts: [
        // Default: full sidebar, used by any page with no layout key (e.g. about).
        CustomDocsLayout(
          siteHeader: const SiteNavbar(),
          sidebar: const DynamicSidebar(sections: [_guides, _useCases, _api]),
        ),
        // Section-specific layouts — matched by the `layout:` frontmatter key.
        // Every page in a section should declare `layout: guides` (etc.) so it
        // gets a sidebar scoped to that section only.
        CustomDocsLayout(
          layoutName: 'guides',
          siteHeader: const SiteNavbar(activePage: 'guides'),
          sidebar: const DynamicSidebar(sections: [_guides]),
        ),
        CustomDocsLayout(
          layoutName: 'use-cases',
          siteHeader: const SiteNavbar(activePage: 'use-cases'),
          sidebar: const DynamicSidebar(sections: [_useCases]),
        ),
        CustomDocsLayout(
          layoutName: 'api',
          siteHeader: const SiteNavbar(activePage: 'api'),
          sidebar: const DynamicSidebar(sections: [_api]),
        ),
        // HomeLayout is matched by name for pages with `layout: home`.
        const HomeLayout(),
        // RenderStudioLayout is matched by name for pages with `layout: renderstudio`.
        const RenderStudioLayout(),
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
  );
}

// Ensure HeroScene is compiled into the client bundle.
// ignore: unused_element
HeroScene? _ref;
