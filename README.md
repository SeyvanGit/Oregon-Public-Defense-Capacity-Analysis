# Oregon Public Defense Capacity Analysis (OPDC)- Capacity Triage — Reproducible Snapshot Analyses (R)

A lightweight, fully reproducible analysis of Oregon public defense capacity using OPDC’s county-level caseload export. The project produces a ranked, transparent **Capacity Pressure Index**, plus two action-oriented views: **ΔMAC to reach 95%** and the **impact of adding one MAC**. Outputs include publication-ready figures and CSVs suitable for memos, dashboards, and a QGIS utilization map.

_Last updated: September 11, 2025_

---
## 1) What this does (overview)

From a single Excel export (`opdc_caseload_summary_full.xlsx`, sheet “Data”), the script computes:

- **Utilization** = Reported MAC ÷ Prorated MAC (and percent).
- **ΔMAC to 95%** = additional MAC needed to return to a conservative safe operating level if workload remains constant.
- **Cases per MAC** = a mix/throughput proxy (inverse of average case weight).
- **Capacity Pressure Index** = a 0–1 composite after min–max scaling of the three inputs (weights: **0.50** Utilization, **0.30** ΔMAC to 95%, **0.20** Cases/MAC).

It then generates five figures and two CSVs to guide where to place the **next MAC** and how many MAC are needed to stabilize each county or county-group.

---

## 2) Project structure

```
.
├─ analysis.R                 # main analysis script (read → compute → visualize → export)
├─ README.md                  # this file
├─ LICENSE                    # MIT license
├─ OPDC_Capacity_Triage.Rproj # RStudio project file
├─ install.R                  # helper to install packages (optional)
├─ renv.lock                  # minimal lockfile (run `renv::snapshot()` to update)
├─ figs/                      # generated figures (created at runtime)
└─ outputs/                   # generated CSVs (created at runtime)
```

---

## 3) Quick start

1. **Clone** the repo and open in **RStudio** (double-click `OPDC_Capacity_Triage.Rproj`) or set your working directory manually.
2. **Place the Excel file** in your working directory:
   - `opdc_caseload_summary_full.xlsx` (sheet name: `"Data"`)
   - Required columns (exact names per export): `home_county`, `appointed_cases`, `reported_mac`, `prorated_mac`, `utilization_rate`
3. **Install dependencies** (one-time). Either run:
   ```r
   source("install.R")
   ```
   or install manually:
   ```r
   install.packages(c("tidyverse","readxl","janitor","ggrepel","stringr","scales"))
   ```
4. **Run the analysis**:
   ```r
   source("analysis.R")
   ```
   Artifacts appear in `figs/` and `outputs/`.


---

## 4) Methods (short)

- **Utilization** is the clearest indicator of overload (≥100% = over capacity).
- **ΔMAC to 95%** turns overload into a **staffing number** (how many MAC to get safe).
- **Cases per MAC** approximates case mix/throughput (inverse of average case weight).
- **Composite index:** min–max scale each metric to [0,1], then compute  
  `0.5 * utilization + 0.3 * ΔMAC_95 + 0.2 * cases_per_mac`.

**Why those weights?** Utilization is most strongly tied to immediate risk (0.50). ΔMAC makes the metric actionable for budgeting (0.30). Cases/MAC is useful but noisier, so it plays a tiebreaker role (0.20). Rankings are stable to modest weight changes (±0.05–0.10).

---

## 5) Interpreting the outputs

- **Figure: `cap_pressure_ranked.png`** — who is most squeezed now (0–100%). Orange = >95% utilization.
- **Figure: `mac_gap_to_95_top12.png`** — staffing units needed to stabilize (ΔMAC to 95%).
- **Figure: `impact_of_one_mac_top12.png`** — where **one MAC** reduces utilization the most (percentage points).
- **Figure: `utilization_ranked.png`** — threshold view; which counties/groups are above/below 95%.
- **Figure: `top10_load_vs_capacity.png`** — context for scale (Appointed Cases vs Reported MAC among large counties).

- **Table: `outputs/capacity_triage_full.csv`** — per-county metrics + index and +1 MAC impact.
- **Table: `outputs/top10_counties_by_appointed_cases.csv`** — top 10 by appointed cases.

---

## 6) Mapping utilization with QGIS (collapsed data approach)

If some dashboard rows represent **county-groups** (e.g., *Baker–Union*, *Klamath–Lake*), collapse the data first (sum numerators, recompute ratios), then paint the **same collapsed value** across member counties in QGIS.

**Workflow summary:**
1. Build a `county_membership.csv` with two columns: `county_name`, `map_unit` (group label).  
2. In R, left-join membership to the caseload table, **group by `map_unit`**, and compute:
   - `Reported_sum`, `Prorated_sum`, `Appointed_sum`  
   - `Utilization = Reported_sum / Prorated_sum`  
   - `util_pct = Utilization * 100`  
   - `cases_per_mac = Appointed_sum / Reported_sum`
3. Export `collapsed_utilization.csv` and join to Oregon counties in QGIS:
   - Join counties → membership (to attach `map_unit`), then counties → collapsed table (on `map_unit`).  
   - Style a **Graduated** choropleth on `util_pct` with bins at ≤80, 80–95, 95–100, 100–110, >110.
4. Optional: **Dissolve** by `map_unit` if you prefer single polygons per group for publication.

---

## 7) Good practice & caveats

- This is a **snapshot**; late reports or contractor shut-offs can temporarily distort utilization.
- Some rows are **county-groups**; allocate at the group level or apportion using a transparent rule (e.g., recent workload shares).
- Min–max scaling can be influenced by outliers; if needed, winsorize tails before scaling.
- The by-case matrix is excluded here; add custody/offense risk when complete.

---

## 8) Reproducibility

- A minimal `renv.lock` is included. After your first successful run, execute:
  ```r
  if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")
  renv::init(bare = TRUE)
  renv::snapshot()
  ```
  to record your exact package versions. Commit the updated `renv.lock`.
- Alternatively, rely on `install.R` and keep the dependency list short and explicit.

---

## 9) Data glossary (plain language)

- **MAC (Maximum Attorney Caseload):** capacity unit for one full-time attorney using OPDC weights.  
- **Prorated MAC:** contracted capacity adjusted for FTE and partial-year timing; excludes supervision/specialty courts.  
- **Reported MAC:** weighted appointments reported to OPDC.  
- **Utilization:** Reported ÷ Prorated (100% at capacity; >100% over capacity).  
- **Appointed cases:** unweighted case count.  
- **Cases per MAC:** cases handled per unit of weighted workload (inverse of average case weight).  
- **ΔMAC to 95%:** additional MAC needed to be at or under 95% utilization if workload is unchanged.  
- **Capacity Pressure Index:** 0–1 composite (50% Utilization, 30% ΔMAC, 20% Cases/MAC).

---

## 10) License

MIT (see `LICENSE`).

---

## 11) Citation

>  Nouri, Seyvan. “OPDC Capacity Triage — Reproducible Snapshot Analyses (R).” SeyvanGit, 2025. URL: *https://github.com/SeyvanGit/Oregon-Public-Defense-Capacity-Analysis*.
>  **Interactive Data**: https://app.powerbigov.us/view?r=eyJrIjoiZDY5MzNiNDAtNDI0NS00NDg1LTk5OTgtYjRiZGVmZmVlNWNlIiwidCI6IjliM2ExODIyLWM2ZTAtNDdjNy1hMDg5LWZiOThkYTc4ODdiZSJ9&pageName=fb6fc95229f8beb31f5f

---

