#ifndef FLASH_EXPORT_H
#define FLASH_EXPORT_H

// Marks the symbols Dart binds to.
//
// On Windows nothing is exported from a DLL unless it is declared
// dllexport, so without this the build succeeds and produces a library with
// no usable entry points. On the ELF/Mach-O side this keeps the intent
// explicit and survives -fvisibility=hidden if that is ever turned on.
//
// Only functions actually called from Dart are marked. Internal helpers
// (broadphase, solver internals) stay off the export surface on purpose.

#if defined(_WIN32)
  #define FLASH_API __declspec(dllexport)
#else
  #define FLASH_API __attribute__((visibility("default")))
#endif

#endif // FLASH_EXPORT_H
