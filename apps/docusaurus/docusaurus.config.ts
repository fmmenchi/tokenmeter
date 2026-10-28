import type { Config } from '@docusaurus/types';
import type * as Preset from '@docusaurus/preset-classic';

const config: Config = {
  title: 'tokenmeter',
  tagline: 'Remaining AI quota for Claude and ChatGPT, in a macOS widget',
  url: 'https://fmmenchi.github.io',
  baseUrl: '/tokenmeter/',
  onBrokenLinks: 'throw',
  markdown: { mermaid: true, hooks: { onBrokenMarkdownLinks: 'throw' } },
  themes: ['@docusaurus/theme-mermaid'],
  presets: [
    [
      'classic',
      {
        // The docs live at the repository root so ADRs are plain files in docs/adr,
        // readable without building the site.
        docs: {
          path: '../../docs',
          routeBasePath: '/',
          sidebarPath: './sidebars.ts',
        },
        blog: false,
        theme: {},
      } satisfies Preset.Options,
    ],
  ],
  themeConfig: {
    navbar: {
      title: 'tokenmeter',
      items: [{ to: '/', label: 'Docs', position: 'left' }],
    },
  },
} satisfies Config;

export default config;
