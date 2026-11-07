"""Compare a copied model response with the exact version persisted on the owned Simulator."""

from pathlib import Path
import json
import sqlite3
import subprocess

from local_evidence import digest


def snapshot(device: str, app_id: str, patient: str) -> dict | None:
    if app_id != "com.medical.doglyad.local" or not patient.startswith("Regression "):
        raise ValueError("Report evidence requires the isolated synthetic report")
    container = Path(
        subprocess.check_output(
            ["xcrun", "simctl", "get_app_container", device, app_id, "data"], text=True
        ).strip()
    )
    with sqlite3.connect(
        (container / "Library/Application Support/default.store").as_uri() + "?mode=ro",
        uri=True,
    ) as db:
        db.row_factory = sqlite3.Row
        reports = db.execute(
            "SELECT r.* FROM ZUSEXAMINATIONREPORTDB r JOIN ZUSEXAMINATIONDATADB d ON d.Z_PK=r.ZEXAMINATIONDATA WHERE d.ZPATIENTNAME=?",
            (patient,),
        ).fetchall()
        if not reports:
            return None
        if len(reports) != 1:
            raise ValueError("The saved report was duplicated")
        report = reports[0]
        relation = next(
            row[1]
            for row in db.execute("PRAGMA table_info(ZUSEXAMINATIONMODELREPORTDB)")
            if row[1].endswith("PREVIOUSMODELREPORTS")
        )
        versions = db.execute(
            f'SELECT m.*, g.ZSTATUS AS STATUS FROM ZUSEXAMINATIONMODELREPORTDB m LEFT JOIN ZUSREPORTGENERATIONDB g ON g.Z_PK=m.ZGENERATION WHERE m.Z_PK=? OR m."{relation}"=? ORDER BY m.ZDATE,m.Z_PK',
            (report["ZACTUALMODELREPORT"], report["Z_PK"]),
        ).fetchall()
        photo_relation = next(
            row[1]
            for row in db.execute("PRAGMA table_info(ZUSEXAMINATIONSCANPHOTODB)")
            if row[1].endswith("PHOTOS")
        )
        photos = [
            dict(row)
            for row in db.execute(
                f'SELECT ZID,ZDATA FROM ZUSEXAMINATIONSCANPHOTODB WHERE "{photo_relation}"=? ORDER BY ZID',
                (report["ZEXAMINATIONDATA"],),
            )
        ]
        data = dict(
            db.execute(
                "SELECT * FROM ZUSEXAMINATIONDATADB WHERE Z_PK=?",
                (report["ZEXAMINATIONDATA"],),
            ).fetchone()
        )
        for key in ["Z_PK", "Z_OPT", "Z_ENT"]:
            data.pop(key, None)
        return dict(
            id=bytes(report["ZID"]).hex(),
            examinationSha256=digest(dict(fields=data, photos=photos)),
            photoCount=len(photos),
            versions=[
                dict(
                    id=bytes(row["ZID"]).hex(),
                    actual=row["Z_PK"] == report["ZACTUALMODELREPORT"],
                    modelId=row["ZMODELID"],
                    status=row["STATUS"],
                    description=row["ZREPORTDESCRIPTION"],
                    conclusion=row["ZCONCLUSION"],
                    recommendations=row["ZRECOMMENDATIONS"],
                    descriptionRemarks=row["ZDESCRIPTIONREMARKS"],
                )
                for row in versions
            ],
        )


def verify(
    before: dict | None, after: dict | None, expected: dict, clipboard: str
) -> dict:
    if after is None:
        raise ValueError("The saved report is missing")
    versions = after["versions"]
    actual = [item for item in versions if item["actual"]]
    if (
        len(actual) != 1
        or actual[0]["status"] != "completed"
        or actual[0]["modelId"] != expected["actualModel"]
    ):
        raise ValueError("The current response does not match the completed model")
    if len(versions) != expected["versionCount"] or len(
        {item["id"] for item in versions}
    ) != len(versions):
        raise ValueError("The response history contains missing or duplicate versions")
    for state, key in [("completed", "completedCount"), ("failed", "failedCount")]:
        if sum(item["status"] == state for item in versions) != expected[key]:
            raise ValueError("Unexpected generation state in saved response history")
    if expected.get("preserveExamination") and (
        before is None
        or before["id"] != after["id"]
        or before["examinationSha256"] != after["examinationSha256"]
    ):
        raise ValueError("Regeneration changed the original examination or photos")
    contents = [
        {key: value for key, value in item.items() if key != "actual"}
        for item in versions
    ]
    if before and any(
        {key: value for key, value in item.items() if key != "actual"} not in contents
        for item in before["versions"]
    ):
        raise ValueError("An existing response was changed or lost")
    if expected.get("distinctResponses"):
        completed = [item for item in versions if item["status"] == "completed"]
        texts = [
            digest(
                {
                    key: item[key]
                    for key in [
                        "description",
                        "conclusion",
                        "recommendations",
                        "descriptionRemarks",
                    ]
                }
            )
            for item in completed
        ]
        if len(set(texts)) != len(texts):
            raise ValueError(
                "Different response fixtures produced identical copyable text"
            )
    selected = [
        item
        for item in versions
        if item["modelId"] == expected["clipboardModel"]
        and item["status"] == "completed"
    ]
    if len(selected) != 1:
        raise ValueError("The copied version is ambiguous")
    l10n = json.loads(
        (
            Path(__file__).resolve().parents[2]
            / "backend/main/config/development/ru/l10n_application.json"
        ).read_text()
    )
    fields = [
        ("description", "reportDescriptionTitle"),
        ("conclusion", "reportConclusionTitle"),
        ("recommendations", "reportRecommendationsTitle"),
        ("descriptionRemarks", "reportDescriptionRemarksTitle"),
    ]
    full_text = "\n\n".join(
        l10n[key] + "\n" + selected[0][field]
        for field, key in fields
        if selected[0][field] is not None
        and (selected[0][field] or field in {"recommendations", "descriptionRemarks"})
    )
    if not full_text or clipboard != full_text:
        raise ValueError("Clipboard differs from the exact saved response version")
    return dict(
        status="passed",
        expected=expected,
        reportId=after["id"],
        examinationSha256=after["examinationSha256"],
        photoCount=after["photoCount"],
        clipboardSha256=digest(clipboard),
        copiedVersionId=selected[0]["id"],
        versions=[
            {key: item[key] for key in ["id", "actual", "modelId", "status"]}
            for item in versions
        ],
    )
