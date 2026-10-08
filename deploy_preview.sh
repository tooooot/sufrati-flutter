#!/bin/bash
# يبني نسخة الويب وينشرها على https://maeda.wardyat.net/preview/
# (rsync إلى مجلد ثابت لأن flutter build يحذف build/web ويعيد إنشاءه فيفقد ربط الحاوية)
set -e
cd /root/sufrati/app_flutter
export PATH=/root/flutter-sdk/bin:$PATH
[ "$1" = "--no-build" ] || flutter build web --release --base-href /preview/ --no-web-resources-cdn
# Cloudflare يخزّن .js بلا بصمة في الاسم ← رقم إصدار في الروابط (مفتاح التخزين يشمل الاستعلام)
V=$(date +%s)
sed -i -E "s#\"mainJsPath\":\"main\.dart\.js(\?v=[0-9]+)?\"#\"mainJsPath\":\"main.dart.js?v=$V\"#" build/web/flutter_bootstrap.js
sed -i -E "s#flutter_bootstrap\.js(\?v=[0-9]+)?#flutter_bootstrap.js?v=$V#g" build/web/index.html
rsync -a --delete build/web/ preview_out/
echo "✅ https://maeda.wardyat.net/preview/"
