# يسجّل داخل مشروع Xcode: GoogleService-Info.plist (مورد)، Runner.entitlements (Sign in with Apple)، وحد iOS 15.
# يُشغَّل في CI على macOS (gem xcodeproj يأتي مع CocoaPods).
require 'xcodeproj'
proj = Xcodeproj::Project.open('ios/Runner.xcodeproj')
target = proj.targets.find { |t| t.name == 'Runner' }
group = proj.main_group['Runner']
unless group.files.any? { |f| f.path == 'GoogleService-Info.plist' }
  ref = group.new_file('GoogleService-Info.plist')
  target.resources_build_phase.add_file_reference(ref)
end
group.new_file('Runner.entitlements') unless group.files.any? { |f| f.path == 'Runner.entitlements' }
target.build_configurations.each do |c|
  c.build_settings['CODE_SIGN_ENTITLEMENTS'] = 'Runner/Runner.entitlements'
  c.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '15.0'
end
# Crashlytics: رفع رموز التصحيح (dSYM) ليقرأ الانهيار بأسماء الدوال
unless target.shell_script_build_phases.any? { |ph| ph.name == 'Crashlytics dSYM' }
  ph = target.new_shell_script_build_phase('Crashlytics dSYM')
  ph.shell_script = 'RUN="${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"; [ -x "$RUN" ] && "$RUN" || echo "Crashlytics run script not found, skipping dSYM upload"; exit 0'
  ph.input_paths = ['${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}',
                    '$(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)']
end
proj.save
puts 'xcode project registered'
