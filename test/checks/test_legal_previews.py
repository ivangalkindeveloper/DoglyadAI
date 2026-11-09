from pathlib import Path
import base64
import re
import sys
import unittest
from html.parser import HTMLParser

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'scripts'))
from legal_previews import ROOT, generate


class Content(HTMLParser):
    def __init__(self):
        super().__init__()
        self.hidden = 0
        self.words = []

    def handle_starttag(self, tag, attrs):
        if tag in {'style', 'script'}:
            self.hidden += 1

    def handle_endtag(self, tag):
        if tag in {'style', 'script'}:
            self.hidden -= 1

    def handle_data(self, data):
        if not self.hidden and data.strip():
            self.words.append(data.strip())


class LegalPreviewTests(unittest.TestCase):
    def test_offline_documents_preserve_the_entire_checked_in_legal_text(self):
        source = generate()
        matches = re.findall(r'static let (\w+) = String\(\s*data: Data\(\s*base64Encoded: "([A-Za-z0-9+/=]+)"', source)
        self.assertEqual([m[0] for m in matches], ['privacyPolicy', 'termsAndConditions'])
        for (name, encoded), folder in zip(matches, ['privacy-policy', 'terms-and-conditions']):
            with self.subTest(document=name):
                html = base64.b64decode(encoded).decode()
                original, offline = Content(), Content()
                original.feed((ROOT / 'docs/legal' / folder / 'index.html').read_text())
                offline.feed(html)
                self.assertEqual(offline.words, original.words)
                self.assertNotIn('href="../styles.css"', html)
                self.assertNotIn('src="../document.js"', html)
                self.assertEqual(html.count('data:font/woff2;base64,'), 8)
                self.assertIn("new URLSearchParams('lang=ru')", html)
