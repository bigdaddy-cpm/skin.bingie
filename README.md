# Bingie

Kodi skin with Netflix layout.

Kodi repository files can be generated with:

`powershell -ExecutionPolicy Bypass -File .\tools\build-kodi-repo.ps1`

This creates:

- `repo/addons.xml`
- `repo/addons.xml.md5`
- `repo/zips/repository.shawnstoked/...`
- `repo/zips/skin.bingie/...`

The repository addon source lives in `repository.shawnstoked/`.
