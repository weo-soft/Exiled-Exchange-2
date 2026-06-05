import { readFileSync } from 'node:fs'
import { dirname, join } from 'node:path'
import { fileURLToPath } from 'node:url'
import { defineConfig } from 'vitepress'
import { withMermaid } from 'vitepress-plugin-mermaid'

const BASE = '/Exiled-Exchange-2/'
const __dirname = dirname(fileURLToPath(import.meta.url))
const { version: appVersion } = JSON.parse(
  readFileSync(join(__dirname, '../../main/package.json'), 'utf-8'),
)

export default withMermaid(
  defineConfig({
    title: 'Exiled Exchange 2',
    description: 'App for price-checking items in Path of Exile 2',
    base: BASE,
    mpa: true,
    head: [
      ['link', { rel: 'shortcut icon', type: 'image/png', href: `${BASE}favicon.png` }],
      ['meta', { name: 'google-site-verification', content: 'R0xdvBEYFTxfn0RxHhquiA6tBgvshYv3ODk-oNSuq4g' }]
    ],
    markdown: {
      theme: 'light-plus',
      attrs: {
        leftDelimiter: '{:',
        rightDelimiter: '}'
      }
    },
    themeConfig: {
      // logo: 'TODO', https://github.com/vuejs/vitepress/issues/1401
      appVersion,
      github: {
        releasesUrl: 'https://github.com/Kvan7/Exiled-Exchange-2/releases'
      },
      socialLinks: [
        {
          text: 'GitHub',
          color: '#181717',
          link: 'https://github.com/Kvan7/Exiled-Exchange-2'
        }
      ],
      sidebar: [
        {
          items: [{
            text: 'Download',
            link: '/download'
          }, {
            text: 'Quick Start',
            link: '/quick-start'
          }
          ]
        },
        {
          items: [{
            text: 'Chat commands',
            link: '/chat-commands'
          }, {
            text: 'OCR Guide',
            link: '/ocr-guide'
          }]
        },
        {
          items: [{
            text: 'Common issues',
            link: '/issues'
          }, {
            text: 'FAQ',
            link: '/faq'
          }]
        },
        {
          text: 'Developer',
          items: [{
            text: 'Architecture',
            link: '/architecture'
          }, {
            text: 'Building for Linux',
            link: '/building-linux'
          }, {
            text: 'Item capture from game',
            link: '/item-capture'
          }, {
            text: 'Development',
            link: '/development'
          }, {
            text: 'Client log parser',
            link: '/client-log-parser'
          }, {
            text: 'Item data',
            link: '/item-data'
          }, {
            text: 'Command-line options',
            link: '/cmd-flags'
          }]
        }
      ]
    }
  }),
)
