#!/usr/bin/env node
// Renders the web page Punctual shows in the browser (the Google sign-in
// completion page) to PNG for the user guide, from the real template in
// OAuthCompletionPage.swift with the English strings substituted in.
//
// Needs Node and Playwright with Chromium: `npm i -g playwright && npx playwright install chromium`.
// Usage: node Scripts/docs/render-web-pages.js [outDir]
// Default outDir: docs/user-guide/images/web

const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const root = path.resolve(__dirname, '..', '..');
const outDir = path.resolve(process.argv[2] || path.join(root, 'docs/user-guide/images/web'));
const swift = fs.readFileSync(path.join(root, 'Punctual/Calendar/Providers/Google/OAuthCompletionPage.swift'), 'utf8');
const stringsFile = fs.readFileSync(path.join(root, 'Punctual/Resources /Localization /en.lproj/Localizable.strings'), 'utf8');

const strings = {};
for (const m of stringsFile.matchAll(/^"((?:[^"\\]|\\.)+)"\s*=\s*"((?:[^"\\]|\\.)*)";/gm)) {
  strings[m[1]] = m[2].replace(/\\"/g, '"');
}

const escape = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
  .replace(/"/g, '&quot;').replace(/'/g, '&#39;');

// The HTML is the first Swift multi-line string literal after `static func html`.
const body = swift.split('static func html')[1];
const literal = body.match(/return """\n([\s\S]*?)\n\s*"""/);
if (!literal) throw new Error('Could not find the HTML literal in OAuthCompletionPage.swift');
// Swift strips the closing delimiter's indentation from every line.
const closing = body.match(/\n(\s*)"""\n\s*}/);
if (!closing) throw new Error('Could not find the end of the HTML literal in OAuthCompletionPage.swift');
const indent = closing[1].length;
const template = literal[1].split('\n').map((l) => l.slice(indent)).join('\n');

function build(accountEmail) {
  const accountLine = accountEmail ? `<p class="account">${escape(accountEmail)}</p>` : '';
  return template
    .replace(/\\\(escape\("([a-z0-9_]+)"\.loco\(\)\)\)/g, (_, key) => {
      if (!(key in strings)) throw new Error(`Missing string ${key}`);
      return escape(strings[key]);
    })
    .replace('\\(accountLine)', accountLine);
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch();
  const shots = [
    { name: 'oauth-complete', account: 'you@example.com' },
  ];
  for (const shot of shots) {
    const html = build(shot.account);
    for (const scheme of ['light', 'dark']) {
      const page = await browser.newPage({
        viewport: { width: 900, height: 560 },
        deviceScaleFactor: 2,
        colorScheme: scheme,
      });
      await page.setContent(html, { waitUntil: 'load' });
      const file = path.join(outDir, `${shot.name}-${scheme}.png`);
      await page.screenshot({ path: file });
      await page.close();
      console.log(path.relative(root, file));
    }
  }
  await browser.close();
})().catch((err) => { console.error(err); process.exit(1); });
