# Routine blood tests and body scans flag gallstone disease with ~79% accuracy, no imaging needed

**Executive summary**
- Question: can non-imaging clinical measurements flag patients likely to have gallstones before ultrasound?
- Finding: on held-out patients, all three models reach 78–79% accuracy (AUC 0.85–0.89), and none is significantly better. Low vitamin D and high CRP carry the clearest signal.
- So what: a cheap, transparent triage score built from tests that are often already ordered could prioritise who gets imaged first.

![Logistic-regression odds ratios per standard deviation for the ten selected features](figures/key_chart.png)

**Approach**: 319 patients with 38 demographic, bioimpedance and laboratory features (UCI). A 30% test set is held out before any preprocessing. The correlation filter and outlier trimming are fitted on training data only, and ANOVA feature selection runs inside each model pipeline. Logistic regression, random forest and XGBoost are each tuned with `GridSearchCV`, then compared with 10× repeated 5-fold cross-validation and a Nadeau–Bengio corrected paired t-test.

**Key findings**
- Test accuracy: logistic regression 78.1%, random forest 79.2%, XGBoost 79.2% (AUC 0.848 / 0.885 / 0.868)
- No pairwise difference in cross-validated AUC is significant (all p ≥ 0.26), so the interpretable logistic model gives up little
- Each SD lower in vitamin D roughly doubles the odds of gallstones (OR 0.49 per SD increase); each SD higher in CRP multiplies them by 3.2
- With 96 test patients, one patient is worth ~1 percentage point of accuracy, so the gaps between models are within the noise

**Limitations**
- A single hospital and 319 patients; external validation is needed
- Associations, not causes: CRP may rise *because of* gallbladder disease
- Correlated body-composition features make individual coefficients less stable than the model's overall predictions

**Full report**: [PDF](report.pdf) · [Read online](https://kyanite03.github.io/analytics-case-studies/02-gallstone-disease-prediction/report.html) · [source](analysis.qmd)
**Tools**: Python · pandas · scikit-learn · XGBoost · SciPy · matplotlib · Quarto
**Reproduce**: `pip install pandas scikit-learn xgboost scipy matplotlib tabulate jupyter`, then `quarto render analysis.qmd` (data in `data/`, see [data note](data/README.md))
