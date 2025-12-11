Native Top-level Layout
=======================

This directory is a minimal placeholder for the native-only repository layout. When publishing the native repo separately, place the C++ sources and the packaging metadata here.

Suggested layout:

```
native/
├── CMakeLists.txt
├── pyproject.toml
├── src/ (or place your .cpp/.h files here)
└── scripts/
```

For this repository the existing native sources live under `arbitrex/native/`. If you move the native sources to a dedicated native repo, update the CI `working-directory` in `.github/workflows/build_native_windows.yml` accordingly.
