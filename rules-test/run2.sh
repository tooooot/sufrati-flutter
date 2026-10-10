#!/bin/bash
# نسخة صبورة من run.sh عند ازدحام السيرفر: تشغّل jar المحاكي مباشرة وتنتظر المنفذ حتى 6 دقائق (firebase-tools يستسلم بعد 60 ثانية)
cd "$(dirname "$0")"
export PATH=/root/android-toolchain/node/bin:/root/android-toolchain/jdk/bin:$PATH JAVA_HOME=/root/android-toolchain/jdk
cp ../firebase/firestore.rules ./firestore.rules
java -Xmx512m -jar ~/.cache/firebase/emulators/cloud-firestore-emulator-v1.19.8.jar --host 127.0.0.1 --port 8089 > emu.log 2>&1 &
EP=$!
for i in $(seq 1 180); do (echo > /dev/tcp/127.0.0.1/8089) 2>/dev/null && break; sleep 2; done
node --test rules.test.mjs
RC=$?
kill $EP 2>/dev/null
exit $RC
