#!/bin/bash
# بناء أندرويد محلي موقَّع بمفتاح الرفع (المفتاح لا يغادر السيرفر): ./build_android.sh [apk|aab]
set -e
cd "$(dirname "$0")"
export PATH=/root/flutter-sdk/bin:$PATH JAVA_HOME=/root/android-toolchain/jdk ANDROID_HOME=/root/android-toolchain/sdk ANDROID_SDK_ROOT=/root/android-toolchain/sdk GRADLE_USER_HOME=/root/android-toolchain/gradle-home
[ -d android ] || flutter create --platforms=android,ios --org net.wardyat --project-name sufrati .
python3 tools/prepare_native.py android
flutter pub get
case "${1:-apk}" in
  aab) flutter build appbundle --release ;;
  *)   flutter build apk --release ;;
esac
