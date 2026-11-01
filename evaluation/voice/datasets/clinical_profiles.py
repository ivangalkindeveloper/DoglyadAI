from __future__ import annotations

# Author-written scenarios, NOT medically validated reference reports. Values
# stay attached to anatomy and context. No random term/measurement pairing and
# no inferred normality, diagnosis, anthropometry or patient complaints.
# One scenario per type is coverage scaffolding, not a prevalence sample.
PROFILES = (
    (
        "abdominalCavity",
        {"ageYears": 48},
        "Жёлчный пузырь содержит подвижный конкремент 8 мм с акустической тенью. Стенка 2 мм. Общий жёлчный проток 4 мм.",
        "The gallbladder contains a mobile 8 mm calculus with acoustic shadowing. Wall thickness is 2 mm. The common bile duct measures 4 mm.",
    ),
    (
        "abdominalVessels",
        {"ageYears": 65},
        "Брюшная аорта в инфраренальном отделе 24 мм в переднезаднем размере. Пристеночных тромботических масс в этом отделе не выявлено.",
        "The infrarenal abdominal aorta measures 24 mm anteroposteriorly. No mural thrombus is seen in this segment.",
    ),
    (
        "arteriesOfTheLowerExtremities",
        {"ageYears": 61},
        "В правой общей бедренной артерии определяется трёхфазный кровоток. Пиковая систолическая скорость 85 см/с. Левую ногу пока не исследовал.",
        "The right common femoral artery has triphasic flow. Peak systolic velocity is 85 cm/s. The left leg has not yet been examined.",
    ),
    (
        "arteriesOfTheUpperExtremities",
        {"ageYears": 42},
        "Правая лучевая артерия проходима. Кровоток трёхфазный, пиковая систолическая скорость 48 см/с.",
        "The right radial artery is patent. Flow is triphasic, with a peak systolic velocity of 48 cm/s.",
    ),
    (
        "bladder",
        {"ageYears": 57},
        "Мочевой пузырь наполнен, объём 260 мл. В просвете подвижных эхогенных включений не видно.",
        "The bladder is filled, with a volume of 260 ml. No mobile echogenic material is seen in the lumen.",
    ),
    (
        "bladderWithResidualUrineDetermination",
        {"ageYears": 69},
        "До мочеиспускания объём мочевого пузыря 310 мл. После мочеиспускания остаточный объём 45 мл.",
        "Bladder volume before voiding is 310 ml. Postvoid residual volume is 45 ml.",
    ),
    (
        "brachiocephalicVessels",
        {"ageYears": 64},
        "В области левой каротидной бифуркации бляшка толщиной 2 мм. Степень стеноза пока не измерена.",
        "There is a 2 mm thick plaque at the left carotid bifurcation. The degree of stenosis has not yet been measured.",
    ),
    (
        "echocardiography",
        {"ageYears": 55},
        "Конечный диастолический размер левого желудочка 49 мм. Фракция выброса по биплановому методу Симпсона 60 процентов. Жидкости в полости перикарда не выявлено.",
        "Left ventricular end-diastolic diameter is 49 mm. Ejection fraction by the biplane Simpson method is 60 percent. No pericardial effusion is seen.",
    ),
    (
        "eye",
        {"ageYears": 60},
        "Исследую правый глаз. В стекловидном теле подвижные мелкоточечные эхосигналы. Признаков отслойки сетчатки не вижу.",
        "I am examining the right eye. There are mobile fine echoes in the vitreous. I do not see evidence of retinal detachment.",
    ),
    (
        "hipJointsInNewborns",
        {"ageDays": 35},
        "Ребёнку пять недель. Справа угол альфа 63 градуса, угол бета 51 градус. Слева угол альфа 62 градуса, угол бета 52 градуса.",
        "The infant is five weeks old. On the right, the alpha angle is 63 degrees and the beta angle is 51 degrees. On the left, the alpha angle is 62 degrees and the beta angle is 52 degrees.",
    ),
    (
        "hollowOrgansStomachAndIntestines",
        {"ageYears": 32},
        "В доступном осмотру участке терминального отдела подвздошной кишки стенка 3 мм. Перистальтика прослеживается. Остальные отделы оценить мешает газ.",
        "The wall measures 3 mm in the visualized terminal ileum. Peristalsis is present. Gas limits assessment of the remaining segments.",
    ),
    (
        "intracanialArteries",
        {"ageYears": 59},
        "Через правое височное окно средняя мозговая артерия лоцируется. Средняя скорость 55 см/с. Слева удовлетворительного акустического окна нет.",
        "The right middle cerebral artery is visualized through the temporal window. Mean velocity is 55 cm/s. There is no adequate acoustic window on the left.",
    ),
    (
        "joints",
        {"ageYears": 47},
        "Осматриваю правое плечо. Сухожилие надостной мышцы прослеживается непрерывно. В субакромиально-субдельтовидной сумке слой жидкости до 3 мм.",
        "I am examining the right shoulder. The supraspinatus tendon is continuous. There is a fluid layer up to 3 mm in the subacromial-subdeltoid bursa.",
    ),
    (
        "kidneysAdrenalGlandsAndRetroperitonealSpace",
        {"ageYears": 46},
        "Правая почка длиной 112 мм, левая 108 мм. В нижней чашечке правой почки конкремент 5 мм с акустической тенью. Лоханка справа не расширена.",
        "The right kidney is 112 mm long and the left is 108 mm long. There is a 5 mm calculus with acoustic shadowing in the right lower calyx. The right renal pelvis is not dilated.",
    ),
    (
        "lymphNodes",
        {"ageYears": 29},
        "Слева на шее лимфоузел 16 на 6 мм. Форма овальная, эхогенные ворота сохранены. Кровоток преимущественно в области ворот.",
        "There is a 16 by 6 mm lymph node in the left neck. It is oval with a preserved echogenic hilum. Flow is predominantly hilar.",
    ),
    (
        "mammaryGlands",
        {"ageYears": 38},
        "В правой молочной железе на 10 часах, в 3 см от соска, анэхогенное образование 8 на 5 мм. Контур чёткий, стенка тонкая, при цветовом допплеровском картировании внутренний кровоток не определяется.",
        "In the right breast at 10 o'clock, 3 cm from the nipple, there is an 8 by 5 mm anechoic lesion. It has a well-defined margin and a thin wall. No internal flow is detected on color Doppler.",
    ),
    (
        "neurosonography",
        {"ageDays": 21},
        "Ребёнку три недели, осмотр через большой родничок. Передний рог правого бокового желудочка 2 мм, левого 2 мм. Срединные структуры не смещены.",
        "The infant is three weeks old and is examined through the anterior fontanelle. The anterior horn of each lateral ventricle measures 2 mm. There is no midline shift.",
    ),
    (
        "pelvicOrgans",
        {"ageYears": 31, "cycleDay": 8},
        "Восьмой день цикла. Эндометрий 5 мм. В правом яичнике фолликул 12 мм. Свободная жидкость в позадиматочном пространстве не определяется.",
        "This is cycle day eight. The endometrium measures 5 mm. There is a 12 mm follicle in the right ovary. No free fluid is seen in the pouch of Douglas.",
    ),
    (
        "pleuralRegion",
        {"ageYears": 72},
        "Справа в плевральной полости жидкость, максимальное расхождение листков в положении сидя 24 мм. Слева жидкости не выявлено.",
        "There is right pleural fluid, with a maximum pleural separation of 24 mm in the sitting position. No fluid is seen on the left.",
    ),
    (
        "pregnancyFirstTrimester",
        {"ageYears": 28, "gestationalAgeWeeks": 9},
        "По направлению срок беременности девять недель. В полости матки один эмбрион, копчико-теменной размер 23 мм. Сердцебиение определяется, частота 168 в минуту.",
        "The referral gives a gestational age of nine weeks. There is one intrauterine embryo with a crown-rump length of 23 mm. Cardiac activity is present at 168 beats per minute.",
    ),
    (
        "pregnancySecondTrimester",
        {"ageYears": 30, "gestationalAgeWeeks": 20},
        "По направлению двадцать недель беременности. Бипариетальный размер 47 мм, длина бедренной кости 32 мм. Плацента по задней стенке.",
        "The referral gives a gestational age of twenty weeks. Biparietal diameter is 47 mm and femur length is 32 mm. The placenta is posterior.",
    ),
    (
        "pregnancyThirdTrimester",
        {"ageYears": 33, "gestationalAgeWeeks": 32},
        "По направлению тридцать две недели беременности. Головное предлежание. Бипариетальный размер 82 мм, длина бедренной кости 61 мм.",
        "The referral gives a gestational age of thirty-two weeks. The fetus is in cephalic presentation. Biparietal diameter is 82 mm and femur length is 61 mm.",
    ),
    (
        "renalArteries",
        {"ageYears": 58},
        "В устье правой почечной артерии пиковая систолическая скорость 120 см/с. Левую почечную артерию оценить не удалось из-за газа.",
        "Peak systolic velocity at the right renal artery origin is 120 cm/s. Bowel gas prevents assessment of the left renal artery.",
    ),
    (
        "salivaryGlands",
        {"ageYears": 44},
        "В протоке правой поднижнечелюстной железы эхогенное включение 4 мм с акустической тенью. Проксимальнее включения проток расширен до 3 мм.",
        "There is a 4 mm echogenic focus with acoustic shadowing in the right submandibular duct. The duct is dilated to 3 mm proximal to the focus.",
    ),
    (
        "scrotum",
        {"ageYears": 27},
        "Правое яичко 43 на 26 на 22 мм. Кровоток в паренхиме определяется. Справа небольшое количество жидкости между оболочками.",
        "The right testis measures 43 by 26 by 22 mm. Parenchymal blood flow is present. There is a small amount of fluid around the right testis.",
    ),
    (
        "sinuses",
        {"ageYears": 36},
        "В проекции правой верхнечелюстной пазухи визуализируется задняя стенка. Слева задняя стенка не визуализируется. Причину этого различия по одному признаку не определяю.",
        "The posterior wall is visualized through the right maxillary sinus. The posterior wall is not visualized on the left. I cannot determine the cause of this difference from this finding alone.",
    ),
    (
        "softTissues",
        {"ageYears": 40},
        "В подкожной клетчатке левого предплечья образование 14 на 6 мм с чёткими контурами. При цветовом допплеровском картировании внутренний кровоток не определяется.",
        "There is a well-defined 14 by 6 mm lesion in the subcutaneous tissue of the left forearm. No internal flow is detected on color Doppler.",
    ),
    (
        "thymusGland",
        {"ageMonths": 4},
        "Ребёнку четыре месяца. Тимус визуализируется в переднем средостении. Структура мелкозернистая, очаговых изменений в доступных осмотру отделах не выявлено.",
        "The infant is four months old. The thymus is visualized in the anterior mediastinum. It has a fine granular appearance, with no focal changes in the visualized portions.",
    ),
    (
        "thyroidGland",
        {"ageYears": 41},
        "В нижней трети левой доли щитовидной железы узел 9 на 6 на 5 мм, солидный, гипоэхогенный, с ровными контурами, шире чем выше. Точечных эхогенных включений не вижу.",
        "There is a 9 by 6 by 5 mm solid hypoechoic nodule in the lower third of the left thyroid lobe. It has smooth margins and is wider than tall. No punctate echogenic foci are seen.",
    ),
    (
        "veinsOfTheLowerExtremities",
        {"ageYears": 63},
        "Правая подколенная вена не полностью сжимается датчиком. В просвете пристеночные массы, кровоток по оставшемуся просвету определяется.",
        "The right popliteal vein is incompletely compressible. There is mural material in the lumen, with flow in the remaining lumen.",
    ),
    (
        "veinsOfTheUpperExtremities",
        {"ageYears": 52},
        "Левые плечевая и подмышечная вены сжимаются полностью. Внутрипросветных масс не выявлено. Подключичная вена проходима по цветовому допплеровскому картированию.",
        "The left brachial and axillary veins are fully compressible. No intraluminal material is seen. The subclavian vein is patent on color Doppler.",
    ),
)
