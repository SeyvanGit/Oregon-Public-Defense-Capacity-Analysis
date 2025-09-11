# analysis.R
# Reproducible snapshot analyses for OPDC/OJD dashboard exports

# ---- setup ----
packages <- c("tidyverse", "readxl", "janitor", "ggrepel", "stringr")
invisible(lapply(packages, library, character.only = TRUE))

setwd("C:/Users/XX/XX/XX/LPDC/Data") # Please set replace it with yours

# file paths (edit if yours differ)
caseload_path <- "opdc_caseload_summary_full.xlsx"          # sheet "Data"
bycase_path   <- "unrepresented_by_case_type_with_jail.xlsx" # sheet "Data"

dir.create("outputs", showWarnings = FALSE)
dir.create("figs", showWarnings = FALSE)


# --- Inputs (edit paths if needed)
caseload <- read_excel("opdc_caseload_summary_full.xlsx", sheet = "Data") |> clean_names()
#bycase   <- read_excel("unrepresented_by_case_type_with_jail.xlsx", sheet = "Data") |> clean_names()

# utilization is stored as a decimal (0.88 == 88%)
cl <- caseload |> mutate(utilization_pct = utilization_rate * 100)

top10 <- cl |> 
  filter(home_county != "Total") |> 
  arrange(desc(appointed_cases)) |> 
  slice_head(n = 10) |> 
  select(home_county, appointed_cases, reported_mac, prorated_mac, utilization_pct)

# Save table
write.csv(top10, "outputs/top10_counties_by_appointed_cases.csv", row.names = FALSE)

# Plot: load vs capacity
p1 <- ggplot(top10, aes(x = reported_mac, y = appointed_cases, label = home_county)) +
  geom_point(size = 2) +
  ggrepel::geom_text_repel(size = 3, max.overlaps = 20) +
  labs(
    title = "Top 10 Counties: Appointed Cases vs. Reported MAC",
    x = "Reported MAC",
    y = "Appointed Cases"
  ) +
  theme_minimal()

ggsave("figs/top10_load_vs_capacity.png", p1, width = 7, height = 4.5, dpi = 300)


####################################################

###################################################


# dapi.R — builds a ranked triage list with components & ΔMAC to 95%

scale01 <- function(x) {
  rng <- range(x, na.rm = TRUE)
  if (diff(rng) == 0) return(rep(0.5, length(x)))
  (x - rng[1]) / diff(rng)
}


# ---- Capacity pressure ----
cap <- caseload |>
  filter(home_county != "Total") |>
  mutate(
    util = utilization_rate,                              # Reported / Prorated (per definition)
    util_pct = util * 100,
    cases_per_mac = appointed_cases / reported_mac, # “How many cases did we handle per unit of weighted workload?”
    mac_gap_to_95 = pmax(0, reported_mac/0.95 - prorated_mac),
    util_new_1mac = reported_mac / (prorated_mac + 1),
    util_drop_1mac = util - util_new_1mac
    
  ) |>
  transmute(
    county = home_county,
    reported_mac,
    prorated_mac,
    appointed_cases,
    util,
    util_pct,
    cases_per_mac,
    mac_gap_to_95,
    util_new_1mac,
    util_drop_1mac
  )


# Capacity pressure (normalize each piece first)
cl_rank <- cap |>
  mutate(
    s_util   = scale01(util),
    s_gap    = scale01(mac_gap_to_95),
    s_cpm    = scale01(cases_per_mac),
    cap_pressure = 0.5*s_util + 0.3*s_gap + 0.2*s_cpm
  ) |>
  arrange(desc(cap_pressure))

write_csv(cl_rank, "outputs/capacity_triage_full.csv")


# 1) Utilization rank
# assumes cl_rank from your script
df_util <- cl_rank %>%
  arrange(util_pct) %>%
  mutate(over_95 = util_pct >= 95,
         county_f = factor(county, levels = county))

p_util <- ggplot(df_util, aes(x = county_f, y = util_pct)) +
  geom_segment(aes(xend = county_f, y = 95, yend = util_pct),
               linewidth = 0.6, alpha = 0.5) +
  geom_point(aes(color = over_95), size = 2) +
  geom_hline(yintercept = 95, linetype = 2) +
  coord_flip() +
  labs(title = "Utilization by county (ranked)",
       x = NULL, y = "Utilization (%)") +
  theme_minimal() +
  theme(panel.grid.minor = element_blank(), legend.position = "none")
ggsave("figs/utilization_ranked.png", p_util, width = 7, height = 7, dpi = 300)


# 2) MAC gap to 95% (top 12)
top_gap <- cl_rank |> arrange(desc(mac_gap_to_95)) |> slice_head(n=12)

p2 <- ggplot(top_gap, aes(x = reorder(county, mac_gap_to_95), y = mac_gap_to_95)) +
  geom_col() + coord_flip() +
  labs(title="How many MAC to reach 95%?", x=NULL, y="ΔMAC to 95%") +
  theme_minimal()
ggsave("figs/mac_gap_to_95_top12.png", p2, width=7, height=5, dpi=300)



# 3) One-MAC impact (where 1 MAC reduces util the most)
top_drop <- cl_rank |> arrange(desc(util_drop_1mac)) |> slice_head(n=12)
p3 <- ggplot(top_drop, aes(x = reorder(county, util_drop_1mac), y = util_drop_1mac*100)) +
  geom_col() + coord_flip() +
  labs(title="Largest utilization drop from +1 MAC", x=NULL, y="Drop in Utilization (percentage points)") +
  theme_minimal()
ggsave("figs/impact_of_one_mac_top12.png", p3, width=7, height=5, dpi=300)




df <- cl_rank %>%
  arrange(cap_pressure) %>%
  mutate(
    over_95 = util_pct >= 95,
    county_f = factor(county, levels = county),
    label = sprintf("%d%% • ΔMAC95=%.1f", round(util_pct), mac_gap_to_95)
  )

p_cap <- ggplot(df, aes(x = county_f, y = cap_pressure, fill = over_95)) +
  geom_col() +
  coord_flip() +
  scale_y_continuous(labels = percent_format(accuracy = 1)) +  # cap_pressure is 0–1
  scale_fill_manual(values = c(`TRUE` = "#d95f02", `FALSE` = "#6baed6"),
                    labels = c(`TRUE` = "Over 95% util", `FALSE` = "≤95% util"),
                    guide = guide_legend(title = "Utilization")) +
  geom_text(aes(label = label), hjust = 0, nudge_y = 0.01, size = 2) +
  expand_limits(y = max(df$cap_pressure) * 1.12) +
  labs(title = "Capacity Pressure (ranked by county)",
       subtitle = "Composite index: 50% Utilization, 30% ΔMAC to reach 95%, 20% Cases per MAC",
       x = NULL, y = "Capacity pressure (0–100%)") +
  theme_minimal() +
  theme(legend.position = "top",
        panel.grid.minor = element_blank())

ggsave("figs/cap_pressure_ranked.png", p_cap, width = 8, height = 7, dpi = 300)




message("Written: outputs/* and figs/*")
