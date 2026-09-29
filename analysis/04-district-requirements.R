#!/usr/bin/env Rscript
## Simulation extension: the requirements figure, replicated across four case-study
## districts, with the target set to the NATIONAL 2019 percentile.
##
## Setup: four districts share the national SHAPE of the 2024 distribution and
## differ only in where their median sits (-0.2, -0.1, +0.1, +0.2 national SD).
##
## Note why the target matters. If each district restores its OWN 2019 level,
## the offset cancels and all four requirements are identical -- there would be
## nothing to plot. Setting the target to the NATIONAL 2019 percentile turns the
## exercise from RECOVERY into CATCH-UP, and the four districts then face very
## different tasks. That distinction is the substantive point of the figure.
##
## Public data only. Usage: Rscript analysis/04-district-requirements.R [--cell CELL]

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr); library(scales); library(ggrepel)
})

IN <- "tables"; OUT <- "figures/sim"
dir.create(OUT, showWarnings=FALSE, recursive=TRUE)
if (!file.exists(file.path(IN, "sim-quantiles.csv")))
  stop("missing ", file.path(IN, "sim-quantiles.csv"),
       ". Run: Rscript analysis/01-simulations.R", call.=FALSE)
qd <- read.csv(file.path(IN,"sim-quantiles.csv"), stringsAsFactors=FALSE)

## --cell, parsed and validated by parse_cell_arg (config-helpers.R).
source("analysis/config-helpers.R")
CELL <- parse_cell_arg("Math G8", qd$cell)
LO_P   <- 25     # lower target percentile
HI_P   <- 90

z  <- qd[qd$cell==CELL,]; z <- z[order(z$percentile),]
S  <- z$sd2019[1]
q19 <- setNames(z$q2019, z$percentile)
d   <- setNames(z$d,     z$percentile)

districts <- tibble(name=c("District A","District B","District C","District D"),
                    offset=c(-0.2,-0.1,0.1,0.2))

## Requirement to lift a district's own 2024 percentile to the NATIONAL 2019
## value at that percentile, in national SD units.
req <- function(offset, p) {
  own24 <- q19[[as.character(p)]] + d[[as.character(p)]] + offset*S
  (q19[[as.character(p)]] - own24) / S
}

## Program points: each pairs a config benchmark effect with a config
## participation rate, by id (district_requirements_points in
## analysis/config/sim-params.yaml). The "Opt-in tutoring (ITT)" pairing is
## flagged there as unconfirmed.
cfg <- load_sim_config()
benchmarks <- bind_rows(lapply(cfg_get(cfg, "district_requirements_points"), function(pt)
  tibble(label=pt$label,
         g=cfg_point_value(cfg, pt, "g", "benchmarks"),
         c=cfg_point_value(cfg, pt, "c", "participation"))))
kraft <- cfg_kraft2020(cfg)

cs <- seq(0.05, 1, length.out=400)
contours <- bind_rows(lapply(seq_len(nrow(districts)), function(i) {
  o <- districts$offset[i]
  glo <- req(o, LO_P); ghi <- req(o, HI_P)
  lab <- sprintf("%s (%+.1f SD)", districts$name[i], o)
  bind_rows(
    tibble(panel=lab, c=cs, g=glo/cs, which=sprintf("reach national p%d", LO_P)),
    ## A negative requirement means the district is ALREADY above the national
    ## 2019 value at that percentile; there is no curve to draw.
    if (ghi > 0) tibble(panel=lab, c=cs, g=ghi/cs,
                        which=sprintf("reach national p%d", HI_P)) else NULL)
}))

lab_tbl <- bind_rows(lapply(seq_len(nrow(districts)), function(i) {
  o <- districts$offset[i]
  tibble(panel=sprintf("%s (%+.1f SD)", districts$name[i], o),
         glo=req(o, LO_P), ghi=req(o, HI_P))
}))
ordv <- lab_tbl$panel
contours$panel <- factor(contours$panel, levels=ordv)
lab_tbl$panel  <- factor(lab_tbl$panel,  levels=ordv)
pts <- tidyr::crossing(benchmarks, panel=factor(ordv, levels=ordv))

sub <- sprintf(paste("Four districts sharing the national shape of the 2024 distribution, differing only in where",
                     "their median sits.\nTarget here is the NATIONAL 2019 percentile, so this is catch-up, not",
                     "recovery: a district that starts lower must\ngain more. Requirement to reach national p%d",
                     "ranges from %.3f SD to %.3f SD across the four."),
               LO_P, min(lab_tbl$glo), max(lab_tbl$glo))

ann <- lab_tbl %>% mutate(
  txt = ifelse(ghi > 0,
    sprintf("needs %.3f SD (p%d) and %.3f SD (p%d) at full participation", glo, LO_P, ghi, HI_P),
    sprintf("needs %.3f SD (p%d); already above national 2019 at p%d", glo, LO_P, HI_P)))

p <- ggplot() +
  annotate("rect", xmin=-Inf, xmax=Inf, ymin=kraft["p90"], ymax=Inf, fill="grey92") +
  geom_hline(yintercept=kraft, linetype="dotted", colour="grey55") +
  geom_line(data=contours, aes(c, g, colour=which, linetype=which), linewidth=0.85) +
  geom_point(data=pts, aes(c, g), size=1.9, colour="grey15") +
  geom_text_repel(data=pts, aes(c, g, label=label), size=2.35, colour="grey25",
                  seed=1, box.padding=0.35, min.segment.length=0.2,
                  segment.colour="grey65", max.overlaps=20) +
  geom_text(data=ann, aes(x=0.06, y=0.72, label=txt), hjust=0, size=2.5, colour="grey35") +
  facet_wrap(~panel, nrow=2) +
  scale_colour_manual(values=setNames(c("#B2182B","#2166AC"),
                      c(sprintf("reach national p%d", LO_P), sprintf("reach national p%d", HI_P)))) +
  scale_linetype_manual(values=setNames(c("solid","longdash"),
                      c(sprintf("reach national p%d", LO_P), sprintf("reach national p%d", HI_P)))) +
  scale_x_continuous("Participation: share of the district's students who take part",
                     labels=percent_format(accuracy=1), limits=c(0.05,1.02)) +
  scale_y_continuous("Required effect for the treated (national 2019 SD)") +
  coord_cartesian(ylim=c(0, 0.78)) +
  labs(title=sprintf("What it would take to reach the national 2019 distribution: %s", CELL),
       subtitle=sub,
       caption=paste("Hypothetical districts; each is the national 2024 distribution shifted by the stated offset.",
                     "Contours are arithmetic on\nmeasured NAEP quantile differences; points are published program",
                     "parameters. Comparing a mean treated effect to a\npercentile-specific requirement assumes the",
                     "effect transports across the treated distribution. Public NAEP Data Service API.")) +
  theme_minimal(base_size=11) +
  theme(panel.grid.minor=element_blank(), legend.position="top",
        legend.title=element_blank(), legend.text=element_text(size=9),
        strip.text=element_text(face="bold"),
        plot.title=element_text(face="bold", size=13),
        plot.subtitle=element_text(colour="grey30", size=9),
        plot.caption=element_text(colour="grey45", size=7.5, hjust=0))

fn <- file.path(OUT, sprintf("fig12-district-requirements-%s.png",
                             gsub("[^A-Za-z0-9]+","-",tolower(CELL))))
ggsave(fn, p, width=11.5, height=8.2, dpi=200)
message("wrote ", fn)

cat(sprintf("\n%s: requirement to reach the NATIONAL 2019 percentile\n", CELL))
cat(sprintf("%-24s %10s %10s\n", "district", sprintf("g*(p%d)",LO_P), sprintf("g*(p%d)",HI_P)))
for (i in seq_len(nrow(lab_tbl)))
  cat(sprintf("%-24s %10.3f %10.3f%s\n", as.character(lab_tbl$panel[i]),
              lab_tbl$glo[i], lab_tbl$ghi[i],
              ifelse(lab_tbl$ghi[i] <= 0, "  (already above national 2019)", "")))
