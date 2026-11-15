# Data: coral trout reef monitoring

**Part I: `aims_coral_trout_sites_2012.csv` (in repo, 4 KB)**
- Source: Australian Institute of Marine Science (AIMS), Long-Term Monitoring Program visual-census fish data, NERP zoning file `nerp_ltmp_fish_zoning.csv`. <https://apps.aims.gov.au/metadata/view/5be0b340-4ade-11dc-8f56-00008a07204e>
- Licence: AIMS data are released under Creative Commons Attribution. *Data sourced from the Australian Institute of Marine Science (AIMS).*
- Processing: 2012 surveys only; *Plectropomus* counts summed per transect, then over the five transects at each site; site IDs anonymised; three latitude bands (north of 17.9°S, 17.9–19°S, south of 19°S).

**Part II: `archive_unlabelled.txt`, `backup_class2.txt` (not in repo)**
- Simulated counts supplied as teaching data in a university statistics course. They aren't redistributed here. The rendered report shows all results; to re-run Part II, simulate comparable data (a three-component Poisson mixture with λ ≈ 6, 20, 38).
