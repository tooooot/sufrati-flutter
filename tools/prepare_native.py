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
    # أيقونة سفرتي الأصلية (تكيّفية + دائرية + أيقونة الإشعار) بدل أيقونة Flutter الافتراضية
    shutil.copytree(NATIVE / 'android-res', a / 'app' / 'src' / 'main' / 'res', dirs_exist_ok=True)
    shutil.copy(NATIVE / 'google-services.json', a / 'app' / 'google-services.json')
    patch(a / 'settings.gradle.kts', lambda s: s if GS_PLUGIN in s else s.replace(
        'id("com.android.application") version', GS_PLUGIN + ' version "4.4.4" apply false\n    id("com.android.application") version', 1))
    def app(s):
        if GS_PLUGIN not in s:
            s = s.replace('id("com.android.application")\n', 'id("com.android.application")\n    ' + GS_PLUGIN + '\n', 1)
        if 'isCoreLibraryDesugaringEnabled' not in s:
            s = s.replace('sourceCompatibility = JavaVersion.VERSION_17', 'isCoreLibraryDesugaringEnabled = true // flutter_local_notifications\n        sourceCompatibility = JavaVersion.VERSION_17', 1)
            s += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")\n}\n'
        s = s.replace('minSdk = flutter.minSdkVersion', 'minSdk = maxOf(23, flutter.minSdkVersion) // firebase_auth يتطلب 23+')
        if 'import java.util.Properties' not in s:
            s = 'import java.util.Properties\n\n' + s  # `java` داخل سكربت Gradle يشير لإضافة Java، فنستورد الصنف صراحةً
        if 'key.properties' not in s:
            s = s.replace('android {\n', '''val keyProps = Properties().apply {
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
        s = re.sub(r'android:label="[^"]*"', 'android:label="سفرتي"', s, 1)
        perms = ['POST_NOTIFICATIONS', 'SCHEDULE_EXACT_ALARM', 'RECEIVE_BOOT_COMPLETED', 'VIBRATE', 'USE_FULL_SCREEN_INTENT', 'WAKE_LOCK']
        for p_ in perms:
            if f'android.permission.{p_}' not in s:
                s = s.replace('<application', f'<uses-permission android:name="android.permission.{p_}"/>\n    <application', 1)
        if 'ScheduledNotificationReceiver' not in s:
            s = s.replace('</application>', '''    <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
        <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
            <intent-filter>
                <action android:name="android.intent.action.BOOT_COMPLETED"/>
                <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
                <action android:name="android.intent.action.QUICKBOOT_POWERON"/>
                <action android:name="com.htc.intent.action.QUICKBOOT_POWERON"/>
            </intent-filter>
        </receiver>
    </application>''', 1)
        if 'showWhenLocked' not in s:
            s = s.replace('<activity', '<activity\n            android:showWhenLocked="true"\n            android:turnScreenOn="true"', 1)
        if 'roundIcon' not in s:
            s = s.replace('android:icon="@mipmap/ic_launcher"', 'android:icon="@mipmap/ic_launcher"\n        android:roundIcon="@mipmap/ic_launcher_round"', 1)
        return s
    patch(a / 'app' / 'src' / 'main' / 'AndroidManifest.xml', manifest)
    # قالب Flutter يضبط -Xmx8G؛ السيرفر 4GB فقط (قُتل البناء الأول) — نستعمل 1.5GB كبقية بناءات أندرويد عندنا
    patch(a / 'gradle.properties', lambda s: re.sub(r'org\.gradle\.jvmargs=.*', 'org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m', s, 1))

def ios():
    r = ROOT / 'ios' / 'Runner'
    icons = r / 'Assets.xcassets' / 'AppIcon.appiconset'
    shutil.rmtree(icons, ignore_errors=True)
    shutil.copytree(NATIVE / 'ios-appicon', icons)  # أيقونة سفرتي الأصلية
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
