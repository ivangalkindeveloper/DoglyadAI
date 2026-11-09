from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULES = ROOT / 'ios/Doglyad/Application/Module'


class LocalPresentationTests(unittest.TestCase):
    def test_database_and_preloaded_selection_modules_have_no_loading_phases(self):
        paths = [
            'History', 'UserSettings', 'LegalUpdate',
            'Storage/Storage', 'Settings/SettingsAI',
            'Template/TemplateAdd', 'Template/TemplateEdit', 'Template/TemplateList',
            'Select/SelectTemplate', 'Select/SelectNeuralModel', 'Select/SelectTranscriber',
        ]
        for relative in paths:
            with self.subTest(module=relative):
                self.assertEqual(list((MODULES / relative / 'ViewModel/State').glob('*LoadingState.swift')), [])
        self.assertEqual(
            [p.name for p in (MODULES / 'Scan/Scan/ViewModel/State').glob('*LoadingState.swift')],
            ['ScanGenerationLoadingState.swift'],
        )

    def test_provider_status_and_automatic_parsing_do_not_become_separate_screens(self):
        for state in ['PaywallPendingState', 'PaywallPaymentCheckLoadingState', 'ScanSpeechAutomaticParsingLoadingState']:
            self.assertEqual(list(MODULES.rglob(state + '.swift')), [])
