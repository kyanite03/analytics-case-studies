# Data: energy & emissions dashboard

The web dashboard (`web/`, rendered to `site/`) is fully self-contained: `web/prep_data.R` compiles the sources below into the small JSON/PNG files in `web/data/` (committed, ~470 KB). The original Shiny app (`app/`) keeps its own inline tables and needs no data files.

| Data | Source | Licence | In repo? |
|---|---|---|---|
| Electricity generation by source, 1990–2025 | DCCEEW, *Australian Energy Statistics 2024*, Table O | CC BY 4.0 | Yes — `web/data/generation.json` |
| 2030–2050 generation path | AEMO, *2024 Integrated System Plan* (step-change scenario) | AEMO copyright | Yes (summarised in the same file) |
| Emission factors (Mt CO₂-e/TWh) | App defaults (coal 1.01, gas 0.49, other 0.41) | — | Yes — `web/data/factors.json` |
| Non-electricity emissions, 1990–2050 | DCCEEW, *Australia's Emissions Projections 2024* (total minus electricity) | CC BY 4.0 | Yes — `web/data/nonElectric.json` |
| Electrification scenarios (demand + 2050 non-electric endpoint) | Simplified mapping from DCCEEW/AEMO scenarios | — | Yes — `web/data/scenarios.json` |
| Paris targets | Climate Change Act 2022 (−43% vs 2005) and net zero 2050 | — | Yes — `web/data/paris.json` |
| Forest cover | ABARES, *Forests of Australia 2023*, 100 m grid (FOREST=1 cells, 133.6 Mha total) | CC BY 4.0 | Processed — `web/data/forest.png` + `web/data/forestBounds.json` |
| State boundaries | `ozmaps` R package (ABS boundaries), projected to EPSG:3577 | ABS / ozmaps | Yes — `web/data/states.geojson` |

**Forest layer prep**: ABARES forest cells are reclassified from the 100 m grid (EPSG:3577, 1 cell = 1 ha) and aggregated to 5 km cells giving the fraction forested, then written as a green RGBA PNG overlay (alpha = fraction). Run `Rscript web/prep_data.R` to regenerate. It needs the raw ABARES grid at `/home/kai_m/shiny/energy_app/aus_for23` and the VAT table in `_handoff/abares/` (not redistributed here); if those are absent it skips the forest layer and still writes the other files.

Raw source data (not redistributed in this repo): `australian_energy_statistics_2024_table_o.xlsx` and `australias-emissions-projections-2024-chart-data.xlsx` are kept locally.
