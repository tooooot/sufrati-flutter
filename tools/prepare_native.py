#!/usr/bin/env python3
"""يهيّئ مجلدي android/ وios/ (المولَّدين بـ flutter create) لسفرتي — آمن لإعادة التشغيل.
الأندرويد: Google Services + حد أدنى 23 + إذن الإنترنت + اسم التطبيق + توقيع الإصدار من android/key.properties إن وُجد.
iOS: ملف Firebase + مخطط URL لدخول Google + ملف صلاحيات Sign in with Apple + منصة Pods 15.
(تسجيل الملفين الأخيرين داخل مشروع Xcode يتم في CI بـ ios_register.rb لأن pbxproj لا يُعدَّل بالنص.)"""
import pathlib, plistlib, re, shutil, sys
ROOT = pathlib.Path(__file__).resolve().parent.parent
NATIVE = ROOT / 'firebase' / 'native'
GS_PLUGIN = 'id("com.google.gms.google-services")'

def patch(path, fn):
    s = path.read_text(encoding='utf-8'); n = fn(s)
    if n != s: path.write_text(n, encoding='utf-8'); print('patched', path.relative_to(ROOT))

def android():
    a = ROOT / 'android'
    shutil.copy(NATIVE / 'google-services.json', a / 'app' / 'google-services.json')
    patch(a / 'settings.gradle.kts', lambda s: s if GS_PLUGIN in s else s.replace(
        'id("com.android.application") version', GS_PLUGIN + ' version "4.4.4" apply false\n    id("com.android.application") version', 1))
    def app(s):
        if GS_PLUGIN not in s:
            s = s.replace('id("com.android.application")\n', 'id("com.android.application")\n    ' + GS_PLUGIN + '\n', 1)
        s = s.replace('minSdk = flutter.minSdkVersion', 'minSdk = maxOf(23, flutter.minSdkVersion) // firebase_auth يتطلب 23+')
        if 'key.properties' not in s:
            s = s.replace('android {\n', '''val keyProps = java.util.Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

android {
''', 1)
            s = s.replace('    buildTypes {', '''    signingConfigs {
        create("upload") {
            if (keyProps.containsKey("storeFile")) {
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {''', 1)
            s = s.replace('signingConfig = signingConfigs.getByName("debug")',
                          'signingConfig = if (keyProps.containsKey("storeFile")) signingConfigs.getByName("upload") else signingConfigs.getByName("debug")')
        return s
    patch(a / 'app' / 'build.gradle.kts', app)
    def manifest(s):
        if 'android.permission.INTERNET' not in s:
            s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
        return re.sub(r'android:label="[^"]*"', 'android:label="سفرتي"', s, 1)
    patch(a / 'app' / 'src' / 'main' / 'AndroidManifest.xml', manifest)

def ios():
    r = ROOT / 'ios' / 'Runner'
    shutil.copy(NATIVE / 'GoogleService-Info.plist', r / 'GoogleService-Info.plist')
    with open(NATIVE / 'GoogleService-Info.plist', 'rb') as f: reversed_id = plistlib.load(f)['REVERSED_CLIENT_ID']
    with open(r / 'Info.plist', 'rb') as f: info = plistlib.load(f)
    info['CFBundleDisplayName'] = 'سفرتي'
    schemes = info.setdefault('CFBundleURLTypes', [])
    if not any(reversed_id in t.get('CFBundleURLSchemes', []) for t in schemes):
        schemes.append({'CFBundleURLSchemes': [reversed_id]})
    with open(r / 'Info.plist', 'wb') as f: plistlib.dump(info, f)
    with open(r / 'Runner.entitlements', 'wb') as f: plistlib.dump({'com.apple.developer.applesignin': ['Default']}, f)
    proj = ROOT / 'ios' / 'Runner.xcodeproj' / 'project.pbxproj'
    patch(proj, lambda t: re.sub(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;', 'IPHONEOS_DEPLOYMENT_TARGET = 15.0;', t))
    pod = ROOT / 'ios' / 'Podfile'
    if pod.exists(): patch(pod, lambda s: re.sub(r"^#?\s*platform :ios, '[\d.]+'", "platform :ios, '15.0'", s, 1, re.M))

if __name__ == '__main__':
    for target in (sys.argv[1:] or ['android', 'ios']): {'android': android, 'ios': ios}[target]()
