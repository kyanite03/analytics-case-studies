# Interactive dashboard: can Australia's 2050 electricity mix hit net zero?

![Dashboard screenshot](figures/screenshot.png)

**Live demo → [dashboard.ksmarsh.net](https://dashboard.ksmarsh.net)** (coming soon) · current version: [shinyapps.io](https://z0q49p-kai-marsh.shinyapps.io/energy_app/)

**Executive summary**
- Question: what 2050 electricity mix gets Australia to its Paris net-zero target, and how much forest would be needed to offset whatever is left?
- Finding: with AEMO's 2024 step-change mix (5 TWh coal, 35 TWh gas), electricity emissions are small, but total 2050 emissions (118 Mt CO₂) still exceed the roughly 100 Mt/yr the government estimates can realistically be offset. Non-electricity sectors are the binding constraint.
- So what: it turns a technical projection into a scenario tool a non-specialist can explore in a minute.

**Approach**: Historical generation (Australian Energy Statistics) and the AEMO 2024 ISP path to 2050 are combined with per-source emission factors and government non-electricity projections. Users choose a 2050 mix that must sum to AEMO's 500 TWh demand. The app recomputes the emissions path, compares it with Paris commitments (2005 baseline, 2030 target, 2050 net zero), and maps the plantation area needed to offset the residual on a map of Australia.

**Key features**
- Constrained scenario input (the total is validated at 500 TWh) with live recalculation
- Stacked generation-mix area chart, 1990–2050
- Emissions stack (electricity vs non-electricity) against Paris targets, with a pass/fail verdict
- Geospatial offset-area map (sf, ozmaps)

**Limitations**
- Emission factors are fixed per source, and 2030/2040 electricity emissions are linearly interpolated
- Non-electricity emissions are taken from government projections and aren't user-adjustable
- The offset map assumes a uniform sequestration rate (10 t CO₂/ha/yr)

**Companion piece**: [*The Myth of Energy Transitions*](companion-video-essay/script.md), a short data-storytelling video essay (script and slides).
**Tools**: R · Shiny · ggplot2 · dplyr/tidyr · sf · ozmaps · Shinylive (webR)
**Reproduce**: see [`DEPLOY_NOTES.md`](DEPLOY_NOTES.md). In short, `renv::restore()`, then `shiny::runApp("app")` or `shinylive::export("app", "site")`.
