# prep_data.R -- build the JSON/PNG data layer for the static (Quarto + OJS) dashboard.
# Run from web/:  Rscript prep_data.R
# Outputs land in web/data/ and are committed; keep the total under ~1 MB.

library(dplyr); library(tidyr); library(jsonlite); library(sf); library(ozmaps)

options(stringsAsFactors = FALSE)
dir.create("data", showWarnings = FALSE)

# ---------------------------------------------------------------- generation ----
# History 1990-2025 + AEMO 2024 ISP step-change path 2030-2050 (same table as app/app.R)
energy_data0 <- tibble::tribble(
  ~Type, ~`1990`, ~`1995`, ~`2000`, ~`2005`, ~`2010`, ~`2015`, ~`2020`, ~`2025`, ~`2030`, ~`2035`, ~`2040`, ~`2050`,
  "Coal", 121.167, 138.3541, 174.0335, 181.1663, 179.7928, 158.6098, 146, 120, 38, 14, 7, 5,
  "Gas", 14.359, 14.913, 16.245, 23.8029, 44.5878, 52.9169, 55, 42, 30, 37, 34, 35,
  "Wind", 0.0, 0.007, 0.058, 0.885, 5.0517, 11.4665, 20, 40, 129, 155, 183, 205,
  "Solar (incl. Rooftop PV)", 0.0, 0.0189, 0.0435, 0.0778, 0.4745, 5.5313, 21, 55, 98, 125, 149, 180,
  "Other", 4.302, 3.666, 2.481, 7.105, 6.3794, 10.5268, 7, 8, 8, 11, 10, 15,
  "Hydro & Storage", 14.88, 16.239, 16.7205, 15.6127, 13.5492, 13.4456, 15, 20, 37, 47, 55, 60
)
years <- c(1990, 1995, 2000, 2005, 2010, 2015, 2020, 2025, 2030, 2035, 2040, 2050)
gen_long <- energy_data0 %>%
  pivot_longer(-Type, names_to = "year", values_to = "twh") %>%
  mutate(year = as.integer(year))

generation <- list(
  types = energy_data0$Type,
  years = years,
  data = lapply(seq_len(nrow(gen_long)), function(i) as.list(gen_long[i, ]))
)

# ------------------------------------------------------------- emission factors ----
factors <- data.frame(
  Type = c("Coal", "Gas", "Wind", "Solar (incl. Rooftop PV)", "Other", "Hydro & Storage"),
  mt_per_twh = c(1.01, 0.49, 0, 0, 0.41, 0)
)

# -------------------------------------------- non-electric emissions (Mt CO2-e) ----
# DCCEEW Australia's Emissions Projections 2024: total minus electricity, common year grid.
# 1990-2020: as used in the original app (projections vintage).
# 2025/2030/2035/2040: DCCEEW 2024 Figure 1 totals minus Figure 18 electricity emissions.
# 2050: app's long-standing endpoint (90 Mt) -- see assumptions panel; adjustable in sign-off.
non_electric <- data.frame(
  year = c(1990, 1995, 2000, 2005, 2010, 2015, 2020, 2025, 2030, 2035, 2040, 2050),
  mt = c(334, 360, 370, 380, 370, 370, 370, 296, 294, 265, 242, 90)
)
# 2025-2040 cells: DCCEEW 2024 Figure 1 total minus Figure 18 electricity (144.28/58.61/36.81/29.23 Mt).
# 2050 (90 Mt): app endpoint -- sign-off item.

scenarios <- data.frame(
  key = c("low", "central", "high"),
  label = c("Low electrification", "AEMO Step Change (central)", "High electrification"),
  demand_2050_twh = c(400, 500, 620),
  non_electric_2050_mt = c(130, 90, 60)
)

# ------------------------------------------------------------ Paris bars ----
paris <- data.frame(
  label = c("2005 level", "2030 target", "2050 target"),
  mt = c(613.42, 349.65, 0),                       # 43% below 2005 (Climate Change Act 2022)
  detail = c("Historical 2005 (DCCEEW 2024)", "-43% vs 2005 (legislated)", "Net zero")
)

# ------------------------------------------------------------- state outlines ----
states <- ozmaps::ozmap_states %>%
  st_transform(3577) %>%                            # GDA94 / Australian Albers (equal-area)
  st_simplify(preserveTopology = TRUE, dTolerance = 2000)  # 2 km tolerance (metres, EPSG:3577)
if (any(!sf::st_is_valid(states))) states <- st_make_valid(states)
# Write a proper GeoJSON FeatureCollection (not a bare geometry array) so Plot.geo is
# guaranteed a standard GeoJSON input.
if (file.exists("data/states.geojson")) file.remove("data/states.geojson")
st_write(states, "data/states.geojson", driver = "GeoJSON", quiet = TRUE)

# ------------------------------------------------------------- forest layer ----
# ABARES Forests of Australia 2023, 100 m grid EPSG:3577.
# FOREST=1 cells -> aggregate to 2.5 km fraction -> density-ramp RGBA PNG overlay.
raster_dir <- "/home/kai_m/shiny/energy_app/aus_for23"          # grid folder
vat_dbf     <- "../../_handoff/abares/aus_for23.tif.vat.dbf"

if (requireNamespace("terra", quietly = TRUE) && dir.exists(raster_dir) && file.exists(vat_dbf)) {
  library(terra); library(foreign)
  r <- rast(raster_dir)
  vat <- read.dbf(vat_dbf, as.is = TRUE)
  cls <- cbind(vat$VALUE, vat$FOREST)               # 1 = forest, 0 = not
  r <- classify(r, cls)
  frac <- aggregate(r, fact = 25, fun = "mean", na.rm = TRUE)  # 100 m -> 2.5 km
  ext <- ext(frac)
  forest_bounds <- list(xmin = ext[1], ymin = ext[3], xmax = ext[2], ymax = ext[4])
  # Ocean / no-data cells get fraction 0 (transparent) -- do NOT leave them NA,
  # because writeRaster's NAflag would write them as 255 (opaque).
  frac[is.na(frac)] <- 0
  frac <- clamp(frac, 0, 1)
  mk <- function(v) { l <- frac; values(l) <- v; l }
  # Density ramp: fraction forested -> green shade (sparse light green, dense deep green).
  stops <- data.frame(
    t = c(0.02, 0.25, 0.55, 1.0),
    r = c(168,  96,  40,   8),
    g = c(214, 176, 132,  70),
    b = c(136,  84,  58,  20)
  )
  ramp <- function(f, band) {
    val <- approx(stops$t, stops[[band]], xout = f, rule = 2)$y
    round(val / 12) * 12          # quantise to 16 levels -> smaller PNG, same look
  }
  v <- values(frac)
  rgba <- c(mk(ramp(v, "r")), mk(ramp(v, "g")), mk(ramp(v, "b")),
            clamp((frac > 0.01) * 255, 0, 255))
  writeRaster(rgba, "data/forest.png", datatype = "INT1U",
              overwrite = TRUE, NAflag = 255,
              gdal = c("COMPRESS=DEFLATE", "PREDICTOR=2", "ZLEVEL=9"))
  cat("forest.png written; bounds:", unlist(forest_bounds), "\n")
} else {
  cat("SKIPPING forest layer (raster dir or dbf not available; needs access to", raster_dir, ")\n")
  forest_bounds <- NULL
}

# ------------------------------------------------------------------ write all ----
writeLines(toJSON(generation, auto_unbox = TRUE, digits = 8), "data/generation.json")
writeLines(toJSON(factors, auto_unbox = TRUE), "data/factors.json")
writeLines(toJSON(non_electric, auto_unbox = TRUE), "data/nonElectric.json")
writeLines(toJSON(scenarios, auto_unbox = TRUE), "data/scenarios.json")
writeLines(toJSON(paris, auto_unbox = TRUE), "data/paris.json")
writeLines(toJSON(forest_bounds, auto_unbox = TRUE, null = "null"), "data/forestBounds.json")

cat("prep done. data/ contents:\n")
print(list.files("data", full.names = TRUE))
for (f in list.files("data", pattern = "\\.(json|geojson|png)$", full.names = TRUE))
  cat(sprintf("  %-40s %8.1f KB\n", f, file.info(f)$size / 1024))
