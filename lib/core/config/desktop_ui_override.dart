/// Feature flag to force the desktop build to reuse the mobile UI stack.
///
/// Keeping this as a single constant lets us flip the behaviour quickly
/// without deleting any of the desktop-specific code paths.
const bool kUseMobileUIOnDesktop = true;
