# -*- coding: utf-8 -*-
"""يصدّر مكتبة الأنظمة (بايثون في maeda) إلى JSON يقرؤه تطبيق Flutter كأصول محلية —
تحويل آلي لا يدوي: أي تعديل على الأنظمة يُعاد تصديره بهذا السكربت.

    python3 tools/export_programs.py   (من /root/sufrati/app_flutter)
"""
import json
import os
import sys
from fractions import Fraction

MAEDA = "/root/sufrati/maeda"
sys.path.insert(0, MAEDA)
os.environ.setdefault("DB_PATH", "/tmp/claude-export-unused.db")

from app import programs, i18n  # noqa: E402

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "data")
os.makedirs(os.path.join(OUT, "programs"), exist_ok=True)

FIELDS = ("MEAL_SLOTS", "INGREDIENTS", "RECIPES", "WEEKLY_LIMITS", "DAY_TYPE_PATTERN", "COOK_INSTRUCTIONS", "USER_TIPS", "COOK_TIPS")


def _enc(o):
    # الكسور (نصف كوب...) تُحفظ نصاً "1/2" ليقرأها Dart كسراً دقيقاً لا عدداً عشرياً
    if isinstance(o, Fraction):
        return f"{o.numerator}/{o.denominator}" if o.denominator != 1 else o.numerator
    if isinstance(o, (tuple, set)):
        return list(o)
    raise TypeError(f"قيمة غير قابلة للتصدير: {o!r}")


def plain(v):
    return json.loads(json.dumps(v, ensure_ascii=False, default=_enc))


index = []
for pid, meta in programs.PROGRAMS.items():
    index.append({k: meta[k] for k in ("label", "icon", "blurb", "status", "category")} | {"id": pid})
    if meta["module"] is None:
        continue
    data = {f: plain(getattr(meta["module"], f, None)) for f in FIELDS}
    with open(os.path.join(OUT, "programs", f"{pid}.json"), "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)

with open(os.path.join(OUT, "programs_index.json"), "w", encoding="utf-8") as f:
    json.dump({"programs": index, "day_names": programs.DAY_NAMES}, f, ensure_ascii=False, indent=1)

tr = {name: plain(getattr(i18n, name)) for name in dir(i18n)
      if name.isupper() and isinstance(getattr(i18n, name), dict)}
with open(os.path.join(OUT, "i18n.json"), "w", encoding="utf-8") as f:
    json.dump(tr, f, ensure_ascii=False, indent=1)

print(f"exported {sum(1 for p in index if p['status'] == 'active')} programs + i18n ({', '.join(sorted(tr))})")

# الصور المرفوعة فعلياً (من حاوية الإنتاج) — المرحلة 1 تعرضها من سيرفر maeda، وتنتقل لـStorage في المرحلة 2
PHOTOS_JSON = os.environ.get("PHOTOS_JSON")
if PHOTOS_JSON:
    import shutil
    shutil.copy(PHOTOS_JSON, os.path.join(OUT, "photos.json"))
    print("photos.json copied")
