"""Build a reviewable localized candidate; does not modify application files."""
from pathlib import Path
import json
from prepare_screening import RU, EN
D=Path(__file__).resolve().parent
catalogs={}
for lang,prompt in [('ru',RU),('en',EN.replace('in Russian','in English'))]:
 lines=prompt.splitlines()
 catalogs[lang]={
  'reportSystemPrompt':'\n'.join(lines[:3])+'\n',
  'reportRecommendationsPrompt':lines[3]+'\n',
  'reportDescriptionRemarksPrompt':lines[4]+'\n',
  'reportMedicalTermCorrectionPrompt':lines[5]+'\n',
  'reportStructuredOutputPrompt':lines[6]+'\nJSON Schema:\n{schema}\n',
 }
 # The application already supplies plain-text style conditionally. Preserve markdown support.
 catalogs[lang]['reportStructuredOutputPrompt']=catalogs[lang]['reportStructuredOutputPrompt'].replace(' Значения строк — обычный текст.','').replace(' Write all string values in English plain text.','')
(D/'candidate-catalog.json').write_text(json.dumps(catalogs,ensure_ascii=False,indent=2)+'\n')
