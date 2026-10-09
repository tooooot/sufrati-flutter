#!/bin/bash
# يختبر ../firebase/firestore.rules على محاكي Firestore (يحتاج java + node من android-toolchain)
cd "$(dirname "$0")"
export PATH=/root/android-toolchain/node/bin:/root/android-toolchain/jdk/bin:$PATH JAVA_HOME=/root/android-toolchain/jdk
cp ../firebase/firestore.rules ./firestore.rules
npx firebase emulators:exec --only firestore --project demo-sufrati 'node --test rules.test.mjs'
