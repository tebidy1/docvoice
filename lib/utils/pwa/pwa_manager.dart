// Export the class type (which matches both implementations in name/interface ideally)
// But since we are using a factory function approach to avoid class name collisions if they were different
// actually we can just use the conditional import to bind the global getter.

// To make type checking easier, we define an abstract interface or just rely on duck typing if they are identical.
// Here we just re-export the conditional instance getter.

export 'pwa_manager_stub.dart'
    if (dart.library.js_interop) 'pwa_manager_web.dart';
