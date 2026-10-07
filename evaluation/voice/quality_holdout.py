from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

# Authored before model responses. Truth is explicit and never computed by the
# production normalisers. These phrasings are separate from the old audio corpus.
PROFILES: dict[str, list[dict[str, Any]]] = {
    "ru": [
        dict(
            name="Татьяна Гончарова",
            gender="female",
            birth="1956-04-09",
            date="девятое апреля тысяча девятьсот пятьдесят шестого года",
            height=163,
            weight=72.5,
            number="UZ-0012",
            complaints="Боль справа под рёбрами в течение трёх дней. Тошноты нет.",
            description="Печень: правая доля 142 мм, контуры ровные. Эхогенность не повышена. Очаговые образования не выявлены. Портальная вена 11 мм, кровоток сохранён. Свободной жидкости нет.",
        ),
        dict(
            name="Георгий Лебедев",
            gender="male",
            birth="1984-03-04",
            date="4 марта 1984 года",
            height=178,
            weight=84,
            number="00083",
            complaints="Жалоб нет.",
            description="Правая почка 112 на 51 мм. Левая почка 109 на 49 мм. Паренхима справа 16 мм, слева 17 мм. Чашечно-лоханочная система не расширена с обеих сторон. Конкрементов не выявлено. Мочевой пузырь содержит 245 мл мочи, стенка 3 мм.",
        ),
        dict(
            name="Валентина Фролова",
            gender="female",
            birth="2000-02-29",
            date="двадцать девятое февраля двухтысячного года",
            height=169,
            weight=63.2,
            number="A-490",
            complaints="Припухлость слева на шее. Боли и повышения температуры нет.",
            description="Щитовидная железа: правая доля объёмом 6.2 мл, левая 5.8 мл. Перешеек 3 мм. В левой доле узел 8 на 6 на 5 мм с ровными контурами, без кальцинатов. Усиления кровотока в узле нет. Регионарные лимфоузлы не увеличены.",
        ),
        dict(
            name="Константин Власов",
            gender="male",
            birth="1949-11-30",
            date="тридцатое ноября тысяча девятьсот сорок девятого года",
            height=181,
            weight=97,
            number="B-0176",
            complaints="Одышка при подъёме на второй этаж. Боли в груди нет.",
            description="Левый желудочек: конечный диастолический размер 51 мм. Межжелудочковая перегородка 10 мм. Фракция выброса 61 процент. Правый желудочек 28 мм. Перикардиального выпота нет. Митральная регургитация первой степени.",
        ),
        dict(
            name="Лидия Миронова",
            gender="female",
            birth="1971-12-21",
            date="21 декабря 1971 года",
            height=157,
            weight=58,
            number="2026-XY-03",
            complaints="Тянущая боль внизу живота. Кровянистых выделений нет.",
            description="Матка 54 на 41 на 48 мм. Эндометрий 4 мм. Правый яичник объёмом 5.4 мл, левый 4.9 мл. Объёмных образований не выявлено. В позадиматочном пространстве свободная жидкость не определяется.",
        ),
        dict(
            name="Артём Захаров",
            gender="male",
            birth="1993-07-06",
            date="шестое июля тысяча девятьсот девяносто третьего года",
            height=186,
            weight=91.4,
            number="R-0902",
            complaints="Боль в левом колене после нагрузки, без боли в покое.",
            description="В верхнем завороте левого коленного сустава жидкость слоем 5 мм. Синовиальная оболочка не утолщена. Сухожилие четырёхглавой мышцы непрерывное. Подколенной кисты не выявлено. Справа выпота нет.",
        ),
        dict(
            weight=68.5,
            number="00429",
            complaints="Горечь во рту после еды.",
            description="Жёлчный пузырь 74 на 26 мм. Стенка 2 мм. В просвете подвижный конкремент 9 мм с акустической тенью. Общий жёлчный проток 4 мм. Внутрипечёночные протоки не расширены.",
        ),
        dict(
            weight=80,
            number="NE-207",
            complaints="Онемение первого и второго пальцев правой кисти.",
            description="Срединный нерв справа: площадь поперечного сечения 13 мм2. Слева 8 мм2. Непрерывность нерва сохранена. Объёмных образований в карпальном канале нет.",
        ),
        dict(
            complaints="Дискомфорт при глотании, без боли.",
            description="Правая подчелюстная железа 31 на 14 мм, левая 30 на 13 мм. Структура однородная с обеих сторон. Расширения протоков и конкрементов не выявлено.",
        ),
        dict(
            complaints="Жалоб нет.",
            description="Плевральная жидкость справа не определяется. Слева также не определяется. Диафрагма визуализируется с обеих сторон. Дополнительных образований не выявлено.",
        ),
    ],
    "en": [
        dict(
            name="Margaret West",
            gender="female",
            birth="1956-04-09",
            date="the ninth of April nineteen fifty six",
            height=163,
            weight=72.5,
            number="UZ-0012",
            complaints="Right upper quadrant pain for three days. No nausea.",
            description="Liver: right lobe 142 mm, smooth contour. Echogenicity is not increased. No focal lesions. Portal vein 11 mm, flow preserved. No free fluid.",
        ),
        dict(
            name="Daniel Brooks",
            gender="male",
            birth="1984-03-04",
            date="March 4, 1984",
            height=178,
            weight=84,
            number="00083",
            complaints="No complaints.",
            description="Right kidney 112 by 51 mm. Left kidney 109 by 49 mm. Parenchyma measures 16 mm on the right and 17 mm on the left. Neither collecting system is dilated. No calculi. Bladder contains 245 ml of urine, wall thickness 3 mm.",
        ),
        dict(
            name="Rebecca Ellis",
            gender="female",
            birth="2000-02-29",
            date="the twenty ninth of February two thousand",
            height=169,
            weight=63.2,
            number="A-490",
            complaints="Left neck swelling. No pain or fever.",
            description="Thyroid: right lobe volume 6.2 ml, left 5.8 ml. Isthmus 3 mm. Left lobe nodule 8 by 6 by 5 mm with smooth margins and no calcifications. No increased nodule vascularity. Regional lymph nodes are not enlarged.",
        ),
        dict(
            name="Walter Hughes",
            gender="male",
            birth="1949-11-30",
            date="the thirtieth of November nineteen forty nine",
            height=181,
            weight=97,
            number="B-0176",
            complaints="Breathlessness when climbing two flights of stairs. No chest pain.",
            description="Left ventricle: end diastolic diameter 51 mm. Interventricular septum 10 mm. Ejection fraction 61 percent. Right ventricle 28 mm. No pericardial effusion. Grade one mitral regurgitation.",
        ),
        dict(
            name="Helen Price",
            gender="female",
            birth="1971-12-21",
            date="December 21, 1971",
            height=157,
            weight=58,
            number="2026-XY-03",
            complaints="Lower abdominal pulling pain. No vaginal bleeding.",
            description="Uterus 54 by 41 by 48 mm. Endometrium 4 mm. Right ovarian volume 5.4 ml, left 4.9 ml. No masses. No free fluid in the pouch of Douglas.",
        ),
        dict(
            name="Adrian Scott",
            gender="male",
            birth="1993-07-06",
            date="the sixth of July nineteen ninety three",
            height=186,
            weight=91.4,
            number="R-0902",
            complaints="Left knee pain after exercise, without pain at rest.",
            description="Left suprapatellar recess contains a 5 mm layer of fluid. Synovium is not thickened. Quadriceps tendon is continuous. No popliteal cyst. No effusion on the right.",
        ),
        dict(
            weight=68.5,
            number="00429",
            complaints="Bitter taste after meals.",
            description="Gallbladder 74 by 26 mm. Wall 2 mm. Mobile 9 mm calculus with acoustic shadowing. Common bile duct 4 mm. Intrahepatic ducts are not dilated.",
        ),
        dict(
            weight=80,
            number="NE-207",
            complaints="Numbness of the right thumb and index finger.",
            description="Right median nerve cross sectional area 13 mm2. Left 8 mm2. Nerve continuity preserved. No mass in the carpal tunnel.",
        ),
        dict(
            complaints="Swallowing discomfort without pain.",
            description="Right submandibular gland 31 by 14 mm, left 30 by 13 mm. Homogeneous structure on both sides. No duct dilatation or calculi.",
        ),
        dict(
            complaints="No complaints.",
            description="No right pleural fluid. No left pleural fluid. Diaphragm is visible on both sides. No additional masses.",
        ),
    ],
}


def prepare(output: Path, *, confirmation: bool = False) -> None:
    from app.core.language_code import LanguageCode
    from app.model.ultrasound.us_voice_form_generation import USVoiceFormGeneration
    from app.prompt.voice_form import voice_form_prompt, voice_form_system_prompt

    profiles_by_locale = PROFILES
    version = "qualityHoldout-v3"
    if confirmation:
        fixtures = json.loads((Path(__file__).parent / "fixtures/gpu_quality_confirmation.json").read_text())
        profiles_by_locale = {locale: [row for row in fixtures if row["locale"] == locale] for locale in ("ru", "en")}
        version = "qualityConfirmation"
    rows: list[dict[str, Any]] = []
    for locale, profiles in profiles_by_locale.items():
        labels = (
            (
                "Examination number",
                "Patient",
                "Gender",
                "Date of birth",
                "Height",
                "Weight",
                "Complaints",
                "Examination description",
            )
            if locale == "en"
            else (
                "Номер исследования",
                "Пациент",
                "Пол",
                "Дата рождения",
                "Рост",
                "Вес",
                "Жалобы",
                "Описание исследования",
            )
        )
        for index, profile in enumerate(profiles):
            fields: dict[str, Any] = {
                "patientComplaints": profile["complaints"],
                "examinationDescription": profile["description"],
            }
            sections: dict[int, str] = {6: profile["complaints"], 7: profile["description"]}
            if "number" in profile:
                fields.update(examinationNumber=profile["number"], patientWeightKG=profile["weight"])
                sections.update({0: profile["number"], 5: f"{profile['weight']} " + ("kg" if locale == "en" else "кг")})
            if "name" in profile:
                fields.update(
                    patientName=profile["name"],
                    patientGender=profile["gender"],
                    patientDateOfBirth=profile["birth"],
                    patientHeightCM=profile["height"],
                )
                gender = (
                    profile["gender"] if locale == "en" else ("женщина" if profile["gender"] == "female" else "мужчина")
                )
                sections.update(
                    {
                        1: profile["name"],
                        2: gender,
                        3: profile["date"],
                        4: f"{profile['height']} " + ("cm" if locale == "en" else "см"),
                    }
                )
            for pack in ("guided", "reordered", "freeform"):
                if pack != "freeform":
                    order = range(8) if pack == "guided" else (7, 6, 5, 3, 1, 0, 2, 4)
                    text = "\n".join(f"{labels[key]}: {sections[key]}" for key in order if key in sections)
                else:
                    text = profile.get("freeText") or free_text(locale, index, profile)
                rows.append(
                    dict(
                        id=f"{version}-{locale}-{pack}-{index:02d}",
                        locale=locale,
                        pack=pack,
                        scenario="complete" if "name" in profile else "partial",
                        inputVersion="quality-holdout-v3" if not confirmation else "quality-confirmation",
                        inputText=text,
                        expectedFields=fields,
                        schema=json.loads(USVoiceFormGeneration.structured_output()),
                        systemPrompt=voice_form_system_prompt(LanguageCode(locale)),
                        prompt=voice_form_prompt(
                            "Ultrasound examination" if locale == "en" else "Ультразвуковое исследование", text
                        ),
                    )
                )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(json.dumps(row, ensure_ascii=False) + "\n" for row in rows), encoding="utf-8")
    print(f"Prepared {len(rows)} unseen cases, {sum(len(row['expectedFields']) for row in rows)} expected fields")


def free_text(locale: str, index: int, profile: dict[str, Any]) -> str:
    clinical = (
        f"The patient complains of {profile['complaints']} Ultrasound shows {profile['description']}"
        if locale == "en"
        else f"Жалуется на {profile['complaints']} При УЗИ {profile['description']}"
    )
    # Denial needs its own construction rather than 'complains of no complaints'.
    if profile["complaints"] in ("No complaints.", "Жалоб нет."):
        clinical = (
            f"Complaints: {profile['complaints']} Ultrasound shows {profile['description']}"
            if locale == "en"
            else f"Жалобы: {profile['complaints']} При УЗИ {profile['description']}"
        )
    identity = ""
    if "name" in profile:
        if locale == "en":
            identity = (
                f"Today's patient is {profile['name']}, {profile['gender']}, born {profile['date']}. "
                f"Height is {profile['height']} cm; weight is {profile['weight']} kg. "
            )
        else:
            identity = (
                f"Сегодня обследуем пациента {profile['name']}. Пол: "
                + ("женщина" if profile["gender"] == "female" else "мужчина")
                + f". Дата рождения {profile['date']}. Рост составляет {profile['height']} см, масса тела {profile['weight']} кг. "
            )
    metadata = ""
    if "number" in profile:
        metadata = f"Study ID {profile['number']}. " if locale == "en" else f"Номер исследования {profile['number']}. "
        if "name" not in profile:
            metadata += (
                f"Weight is {profile['weight']} kg. " if locale == "en" else f"Вес составляет {profile['weight']} кг. "
            )
    if index % 3 == 0:
        return clinical + " " + identity + metadata
    if index % 3 == 1:
        # No introductory clinical cue: the model must locate a long paragraph.
        complaint = f"Complaints: {profile['complaints']} " if locale == "en" else f"Жалобы: {profile['complaints']} "
        return identity + metadata + complaint + profile["description"]
    return identity + metadata + clinical


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", type=Path)
    parser.add_argument("--confirmation", action="store_true")
    args = parser.parse_args()
    prepare(args.output, confirmation=args.confirmation)
