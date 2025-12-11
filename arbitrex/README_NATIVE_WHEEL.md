Native Extension Wheels (prebuilt)
=================================

This repository produces prebuilt Windows wheels for the native pybind11 extensions to avoid local AV/linker/vcpkg flakiness.

Quick install (after CI build or from Releases/artifacts):

```powershell
pip install path\to\arbitrex-<version>-cp311-*.whl
```

Import in Python:

```python
import native_mt5
native_mt5.init()
rates = native_mt5.copy_rates_from_pos("EURUSD", 60, 0, 100)
```

Local dev builds (skip Arrow helpers):
- Arrow helpers are optional and disabled by default.
- To build locally without Arrow (fast):

```powershell
cd arbitrex
python -m pip wheel . -w dist --global-option=-- -DCMAKE_ARGS="-DBUILD_ARROW=OFF"
```

To create a full Arrow-enabled wheel (CI recommended, heavy & slower):

```powershell
python -m pip wheel . -w dist --global-option=-- -DCMAKE_ARGS="-DBUILD_ARROW=ON"
# ensure vcpkg is bootstrapped and Arrow/Thrift installed
```

CI
--
The GitHub Actions workflow `.github/workflows/build_native_windows.yml` builds wheels for Python 3.10–3.12 and exposes an input `enable_arrow` to build Arrow-enabled artifacts.

Developer flow
--
1. CI builds wheel → upload as artifact or Release.
2. Developers download and `pip install` the wheel.
3. No local native build required; Python imports the prebuilt extension.

Notes
--
- Keep `BUILD_ARROW=OFF` locally to avoid vcpkg/Arrow build paths.
- For production or performance testing, run CI with `enable_arrow=true` to produce full Arrow-enabled wheels.
