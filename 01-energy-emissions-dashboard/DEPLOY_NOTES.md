# Deploy notes: energy emissions dashboard (handoff for DeepCode)

> **Status: the static export (`site/`) is NOT ready yet.** The Shinylive build completes, but in the browser the app fails at startup with `Maximum call stack size exceeded` (webR). It has been narrowed to the offset-map plot (`output$forestMap`): every other output renders, and the map code renders fine in a standalone Shinylive app. Investigation is ongoing, and `site/` will be committed once it runs cleanly. You can prepare the Aliyun/Cloudflare pipeline in the meantime, using the requirements below.

## Rebuild
- R 4.5.3. Package versions are pinned in `app/renv.lock`.
- From this folder:
  ```r
  renv::restore(project = "app")
  shinylive::export("app", "site")
  httpuv::runStaticServer("site")   # local test
  ```
- `shinylive` depends on the `archive` package, which needs libarchive headers (`libarchive-dev`) to compile.

## Deployable artefact
- The **entire** `site/` folder, including `shinylive/` and `shinylive-sw.js` (which must sit at the root of the served path).
- Expected size: about 124 MB, 200+ files. The largest are `shinylive/webr/R.wasm` (17 MB), `webr/packages/sf/*.tgz` (15 MB), `webr/library.data.gz` (14 MB) and `webr/packages/stringi/*.tgz` (13 MB). Exact figures will be updated when `site/` is committed.

## Serving requirements
- HTTPS end to end (the service worker requires it).
- `.wasm` → `application/wasm`; `.js` → `application/javascript`; `.json` → `application/json`.
- Index document: `index.html`.
- The first load downloads about 60–120 MB, so long edge-cache TTLs for `shinylive/*` are worthwhile.

## webR caveats found so far
- `sf` and `ozmaps` work under webR (tested in isolation).
- The forest-cover raster layer was removed. The source raster was empty (all NA), so it never displayed anything, and dropping it removed the `raster`, `terra` and `sp` dependencies.
- Package version mismatch warnings at export (curl 7.0.0 vs 8.0.0, lattice) are harmless; neither is used by the app.

## Test checklist
- [ ] The page loads over HTTPS (first load 10–20 s)
- [ ] All five plots render, including the offset map
- [ ] Changing the 2050 inputs and clicking **Update** redraws the charts; a total other than 500 shows the warning modal
- [ ] "View References" opens the modal
- [ ] No console errors other than webR package-startup messages
