"""Embed the checked-in legal pages and their assets for offline module previews."""

from __future__ import annotations

import base64
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[2]


def generate() -> str:
    directory = ROOT / 'docs/legal'
    css = (directory / 'styles.css').read_text()

    def font(match: re.Match[str]) -> str:
        asset = directory / match[1]
        if asset.parent != directory / 'fonts' or asset.suffix != '.woff2':
            raise ValueError('Unexpected legal-document asset')
        data = base64.b64encode(asset.read_bytes()).decode()
        return "url('data:font/woff2;base64," + data + "')"

    css = re.sub(r"url\('([^']+)'\)", font, css)
    js = (directory / 'document.js').read_text().replace(
        'new URLSearchParams(window.location.search)', "new URLSearchParams('lang=ru')"
    )
    lines = ['// Generated from docs/legal by test/scripts/catalog.py.', '#if DEBUG', '    import Foundation', '', '    enum LegalDocumentPreviewHTML {']
    for name, folder in [('privacyPolicy', 'privacy-policy'), ('termsAndConditions', 'terms-and-conditions')]:
        html = (directory / folder / 'index.html').read_text()
        stylesheet = '<link rel="stylesheet" href="../styles.css">'
        script = '<script src="../document.js"></script>'
        if stylesheet not in html or script not in html:
            raise ValueError('Legal-document asset references changed')
        html = html.replace(stylesheet, '<style>' + css + '</style>').replace(script, '<script>' + js + '</script>')
        encoded = base64.b64encode(html.encode()).decode()
        lines.extend([f'        static let {name} = String(', '            data: Data(', f'                base64Encoded: "{encoded}",', '            )!,', '            encoding: .utf8,', '        )!'])
    lines.extend(['    }', '#endif', ''])
    return '\n'.join(lines)
