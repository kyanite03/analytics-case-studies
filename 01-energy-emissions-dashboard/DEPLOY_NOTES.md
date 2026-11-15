# Deploy notes: energy emissions dashboard (static build)

> **Status: `site/` is a static Quarto + Observable JS page — no webR, no Shiny server.**
> The Shinylive route was dropped after the webR crash investigation (see the local `_handoff/DASHBOARD_OVERHAUL.md`, which is gitignored and never committed). The Shiny source stays in `app/` as the R showcase.

## Rebuild
- Source: `web/` (Quarto project, `output-dir: ../site`). Data layer: `web/prep_data.R` → `web/data/*.json|png` (committed; ~0.5 MB total).
- From `web/`:
  ```bash
  ./render.sh          # Rscript prep_data.R + quarto render + copy data/ into site/
  ```
  `prep_data.R` needs R 4.5.3 with dplyr, tidyr, jsonlite, sf, ozmaps, terra, foreign, and local access to the ABARES grid (`/home/kai_m/shiny/energy_app/aus_for23`) and the VAT dbf in `_handoff/`. If the forest raster isn't available it skips the PNG layer but still writes the other files.
- Local test: `python3 -m http.server 8899` from `site/`, then open http://127.0.0.1:8899/.

## Deployable artefact
- The **entire** `site/` folder: `index.html`, `data/`, `site_libs/`, `search.json`, `styles.css`, `plot.js`.
- Size: about 3 MB total (Quarto libs ~2 MB, `plot.js` 380 KB, data ~0.5 MB incl. `forest.png` 264 KB and `states.geojson` 183 KB). No `.wasm`, no service worker.
- The page shows no OJS source code (`execute: echo: false` in `web/index.qmd`); only the rendered widgets and charts are visible.
- Committed to the repo; `.github/workflows/deploy-dashboard.yml` uploads it to Aliyun OSS bucket `dashboard-emissions` (Hong Kong) on any push to `main` that changes `site/**`. Live URL: **https://emitdb.ksmarsh.net** (Cloudflare DNS → OSS origin).

## Serving requirements
- HTTPS (plain static site; the old service-worker requirement is gone).
- `.js` → `application/javascript`; `.json` → `application/json`.
- Index document: `index.html`.
- Worthwhile: long cache TTLs for `site_libs/**` and `data/**` (they only change on rebuild), short TTL for `index.html`.

## Test checklist
- [ ] The page loads over HTTPS in ~1–3 s
- [ ] All four charts render: generation-mix area, offset map (forest overlay + two to-scale squares), emissions stack, Paris bars; plus the pass/fail card
- [ ] Changing the 2050 inputs updates the running total; **Update** only applies when the total equals the scenario demand, otherwise the warning shows and **Rescale to target** normalises
- [ ] The electrification scenario changes the demand target and the 2050 non-electricity endpoint
- [ ] The sequestration-rate and offset-ceiling sliders update the map squares, caption and pass/fail card
- [ ] "Assumptions & sources" and the references expander are visible
- [ ] No console errors; layout works at phone width
