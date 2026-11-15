# Data: gallstone disease prediction

- **Source:** UCI Machine Learning Repository, *Gallstone* dataset (Esen et al., 2024). 319 patients, Ankara VM Medical Park Hospital, June 2022 – June 2023, 38 features. <https://archive.ics.uci.edu/dataset/1150/gallstone-1>
- **Licence:** CC BY 4.0
- **In repo:** `gallstone_data.csv` (55 KB), used by `analysis.qmd`. It holds the same values as the downloaded spreadsheet (319 rows × 39 columns, no missing values). It was converted to CSV because the original `.xlsx` is saved in Strict Open XML format, which `openpyxl`/pandas cannot read.
