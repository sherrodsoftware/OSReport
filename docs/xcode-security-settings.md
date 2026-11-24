# Xcode Security Settings

Security build settings decisions for OS Report.

## Enabled settings

- `ENABLE_ENHANCED_SECURITY`: Set at the project level so every target inherits it. Also turns on `ENABLE_SECURITY_COMPILER_WARNINGS`, stack zero-initialization and typed allocator support.
- `ENABLE_HARDENED_RUNTIME`: Required for Developer ID notarization. It was already on before this audit.
- Enhanced Security entitlements in `OSReport/OSReport.entitlements` (OSReport app target):
  - `com.apple.security.hardened-process`
  - `com.apple.security.hardened-process.enhanced-security-version-string` to `2`
  - `com.apple.security.hardened-process.hardened-heap`
  - `com.apple.security.hardened-process.dyld-ro`
  - `com.apple.security.hardened-process.platform-restrictions-string` to `2`: Limits dylib loading and Mach messaging. Sparkle installs updates through its own XPC services and `Updater.app`, so test a real update before each release.
- `com.apple.security.hardened-process.checked-allocations` with `checked-allocations.soft-mode`: Hardware memory tagging in soft mode, which writes simulated crash reports instead of terminating. Hardware backing needs a Mac with an M5 chip or later. Turn soft mode off only after the simulated crash reports have been reviewed and fixed.

## Disabled settings

- `ENABLE_POINTER_AUTHENTICATION` to `NO` (target level, OSReport and OSReportTests): Sparkle 2.10 ships only `x86_64` and `arm64` slices for its framework, `Updater.app`, `Autoupdate`, and XPC services, so the app can't link as `arm64e`. The test bundle loads into the app, so it uses the same architectures. Remove both overrides when Sparkle ships an `arm64e` build.
- `ENABLE_HARDWARE_CHECKED_POINTER_ARITHMETIC_SLICE` to `NO` (target level, OSReport and OSReportTests): `arm64e.x1` is a pointer-authentication slice, so it can't be built while pointer authentication is off. Checked pointer arithmetic is also limited to iOS and watchOS, so it wouldn't apply to this macOS app even with pointer authentication.

## Deferred

Settings considered but not yet enabled. Revisit them later.

- Compiler warnings, static analyzer checkers and clang-tidy checks (for example `GCC_WARN_ABOUT_RETURN_TYPE`, `CLANG_ANALYZER_SECURITY_INSECUREAPI_STRCPY`, `CLANG_TIDY_BUGPRONE_REDUNDANT_BRANCH_CONDITION`): These only apply to C, C++ and Objective-C. The project is all Swift. Revisit if C-family code is added.
- Additional diagnostic settings (`CLANG_WARN_SUSPICIOUS_IMPLICIT_CONVERSION`, `CLANG_ANALYZER_SECURITY_BUFFER_OVERFLOW_EXPERIMENTAL`, `CLANG_WARN_ASSIGN_ENUM`, `GCC_WARN_SIGN_COMPARE`): Also C-family only; no effect on this project.
- `ENABLE_C_BOUNDS_SAFETY` and `ENABLE_CPLUSPLUS_BOUNDS_SAFE_BUFFERS`: No C or C++ code.
- `com.apple.security.hardened-process.checked-allocations.enable-pure-data` and `checked-allocations.no-tagged-receive`: Optional memory-tagging extensions. Consider them after soft mode has run cleanly.
