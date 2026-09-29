#!/usr/bin/env Rscript
## Simulation figures. Reads tables/sim-quantiles.csv and tables/sim-bottom-decile.csv
## written by 01-simulations.R, and the program points from the config.
##
## Figure 8: the requirements figure. Coverage on x, treated effect size on y,
##   iso-restoration contours for p10 and p90, with real programs plotted at
##   their evidenced (coverage, effect) pairs. Nothing on this figure is
##   simulated: contours are arithmetic on measured quantile differences, and
##   the points are published program parameters.
##
## Figure 9: quantile-difference curves for all six cells, with the restoration
##   requirement read on a second axis.
##
## Usage: Rscript analysis/02-figures.R [--in tables] [--out figures/sim]

suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tidyr); library(scales); library(ggrepel)
})

args <- commandArgs(trailingOnly=TRUE)
getarg <- function(f,d){i<-match(f,args); if(is.na(i)) d else args[i+1]}
IN  <- getarg("--in","tables"); OUT <- getarg("--out","figures/sim")
dir.create(OUT, showWarnings=FALSE, recursive=TRUE)

## Read the CSVs written by 01-simulations.R. The .rds is convenient but
## .gitignore excludes *.rds as a restricted-data backstop, so the CSVs are
## the version-controlled, reproducible inputs. Both contain only published
## aggregate statistics.
qd_path <- file.path(IN, "sim-quantiles.csv")
bd_path <- file.path(IN, "sim-bottom-decile.csv")
if (!file.exists(qd_path))
  stop("Missing ", qd_path, ". Run: Rscript analysis/01-simulations.R")

qd <- read.csv(qd_path, stringsAsFactors=FALSE) %>%
  transmute(cell, p=percentile, q19=q2019, d, se=d_se,
            g=g_star, gse=g_star_se, S=sd2019)
tg_raw <- if (file.exists(bd_path)) read.csv(bd_path, stringsAsFactors=FALSE) else NULL
PS <- sort(unique(qd$p))

ord <- c("Reading G4","Reading G8","Reading G12","Math G4","Math G8","Math G12")
qd$cell <- factor(qd$cell, levels=ord)

## Featured cells lead; the others are the supplement.
feat <- c("Reading G4","Reading G8","Math G4","Math G8")

## Program points. TWO participation denominators, and they are NOT
## interchangeable. Sources report one or the other, rarely both.
##
##   share_all      = tutored students / ALL students in the population
##   share_targeted = tutored students / students the program TARGETED
##
## The distinction matters for this figure because the requirement contour is
## defined over the population a percentile represents. A program reaching
## 25 percent of a targeted bottom quartile reaches about 6 percent of all
## students, and those are very different points on the x axis.
##
## `basis` records which denominator the SOURCE actually reports; `share_all`
## is the plotted quantity, derived where a conversion is defensible and left
## NA where it is not. Nothing here is silently converted.
##
## The points themselves, with a comment per point on which denominator its
## source reports and why, live in analysis/config/sim-params.yaml
## (requirements_figure_points). Effects and rates that are also config
## benchmarks or participation rates are referenced there by id, so a revised
## parameter moves this figure along with every table.
source("analysis/config-helpers.R")
cfg <- load_sim_config()
benchmarks <- bind_rows(lapply(cfg_get(cfg, "requirements_figure_points"), function(pt)
  tibble(label=pt$label,
         g=cfg_point_value(cfg, pt, "g", "benchmarks"),
         share_all=cfg_point_value(cfg, pt, "share_all", "participation"),
         share_targeted=cfg_point_value(cfg, pt, "share_targeted", "participation"),
         basis=cfg_get(pt, "basis"), src=cfg_get(pt, "src"))))

## Kraft (2020) empirical distribution of 1,942 education RCT effects.
kraft <- cfg_kraft2020(cfg)

theme_sim <- theme_minimal(base_size=11) +
  theme(panel.grid.minor=element_blank(),
        plot.title=element_text(face="bold", size=13),
        plot.subtitle=element_text(colour="grey30", size=10),
        plot.caption=element_text(colour="grey45", size=8, hjust=0),
        strip.text=element_text(face="bold"))

## ---- Figure 8: the requirements figure ------------------------------------
## Only points that carry BOTH an effect and a share-of-all-students
## participation rate can go on this axis. Points reported as a share of the
## TARGETED population (Carbonari, Robinson) are excluded here and reported in
## the text instead, because plotting them against a population-denominated
## contour would overstate their reach several-fold.
plotpts <- benchmarks %>%
  filter(!is.na(g), !is.na(share_all)) %>%
  mutate(basis = ifelse(basis == "both", "measured", basis))
excluded <- benchmarks %>% filter(is.na(g) | is.na(share_all))

## lo_p is the lower target percentile. p10 is the deepest deficit; p25 is the
## more policy-relevant target, because eligibility screens can plausibly reach
## the bottom quartile while no screen isolates the bottom decile.
mk_fig8 <- function(cell_lab, lo_p = 10, hi_p = 90) {
  glo <- qd %>% filter(cell==cell_lab, p==lo_p) %>% pull(g)
  ghi <- qd %>% filter(cell==cell_lab, p==hi_p) %>% pull(g)
  cs  <- seq(0.05, 1, length.out=400)
  contours <- bind_rows(
    tibble(c=cs, g=glo/cs,
           which=sprintf("restore p%d (needs %.3f SD at full participation)", lo_p, glo)),
    tibble(c=cs, g=ghi/cs,
           which=sprintf("restore p%d (needs %.3f SD at full participation)", hi_p, ghi)))
  ggplot() +
    annotate("rect", xmin=-Inf, xmax=Inf, ymin=kraft["p90"], ymax=Inf,
             fill="grey92") +
    annotate("text", x=1.0, y=kraft["p90"]+0.02, hjust=1, vjust=0, size=2.7,
             colour="grey45", label="above the 90th pctile of observed education effects") +
    geom_hline(yintercept=kraft, linetype="dotted", colour="grey55") +
    annotate("text", x=0.06, y=kraft, hjust=0, vjust=-0.4, size=2.6, colour="grey45",
             label=sprintf(c("median observed effect (%.2f)","P75 (%.2f)","P90 (%.2f)"), kraft)) +
    geom_line(data=contours, aes(c, g, colour=which, linetype=which), linewidth=0.9) +
    ## Program points disabled; figure now shows only the Kraft (2020)
    ## reference lines and the restoration contours.
    # geom_point(data=plotpts, aes(share_all, g, shape=basis), size=2.8, fill="white",
    #            colour="grey15", stroke=0.9) +
    # scale_shape_manual(values=c(measured=21, assumed=24, borrowed=22),
    #                    labels=c(measured="participation measured in the same study",
    #                             assumed="participation is a modelling assumption",
    #                             borrowed="effect and participation from different studies")) +
    # ggrepel::geom_text_repel(data=plotpts, aes(share_all, g, label=label),
    #                          size=2.9, colour="grey15", seed=1,
    #                          box.padding=0.5, min.segment.length=0.2) +
    scale_colour_manual(values=c("#B2182B","#2166AC")) +
    scale_linetype_manual(values=c("solid","longdash")) +
    scale_x_continuous("Intervention Participation Rate as a Share of All Students",
                       labels=percent_format(accuracy=1), limits=c(0.05,1.02)) +
    scale_y_continuous("Required effect for the treated (2019 national SD)") +
    ## coord_cartesian CLIPS THE VIEW without dropping data. With
    ## scale_y_continuous(limits=) ggplot deletes rows first, so the p10
    ## contour was being erased below ~34% coverage -- exactly where every
    ## real program sits, and exactly where the argument lives.
    coord_cartesian(ylim=c(0, 0.75)) +
    labs(title=sprintf("What it would take to restore 2019: %s", cell_lab) ## ,
         ## subtitle=sprintf(paste("A program must sit ON or ABOVE a curve to restore that percentile.",
         ##                       "\nNo observed program comes close for the %dth percentile."), lo_p)
         ## caption=paste("Contours are arithmetic on measured NAEP quantile differences. Points show published program",
         ##              "parameters,\nplotted as a share of ALL students. Programs whose participation is reported only as a share of the",
         ##             "TARGETED\npopulation (Carbonari et al. 2025: 1-2% of eligible for effective tutoring, 32% for expert-teacher",
         ##              "assignment;\nRobinson et al. 2025: 18.7% take-up) are omitted, since that denominator is not comparable.",
         ##              "Comparing a mean\ntreated effect to a percentile-specific requirement assumes the effect transports across the treated",
         ##              "distribution.")
         ) +
    theme_sim + theme(legend.position="top", legend.title=element_blank(),
                     legend.text=element_text(size=8), legend.box="vertical",
                     legend.spacing.y=unit(1,"pt"))
}

for (cl in feat) {
  for (lo in c(10, 25)) {
    p <- mk_fig8(cl, lo_p=lo)
    fn <- file.path(OUT, sprintf("fig8-requirements-p%d-%s.png", lo,
                                 gsub("[^A-Za-z0-9]+","-",tolower(cl))))
    ggsave(fn, p, width=8.2, height=6.0, dpi=200)
    message("wrote ", fn)
  }
}

## ---- Figure 9: QD curves, all six cells -----------------------------------
f9 <- ggplot(qd, aes(q19, d)) +
  geom_hline(yintercept=0, colour="grey40") +
  geom_ribbon(aes(ymin=d-1.96*se, ymax=d+1.96*se), fill="#2166AC", alpha=0.18) +
  geom_line(colour="#2166AC", linewidth=0.7) +
  geom_point(colour="#2166AC", size=2) +
  geom_text(aes(label=paste0("p",p)), vjust=-1.1, size=2.7, colour="grey35") +
  facet_wrap(~cell, scales="free_x", nrow=2) +
  scale_y_continuous("2024 minus 2019 (NAEP score points)") +
  scale_x_continuous("2019 quantile value (NAEP scale)") +
  labs(title="The decline is concentrated at the bottom of every distribution",
       subtitle="Quantile-difference curves, national. Upward slope = larger losses at the bottom.\nBands are 95% intervals from published NAEP standard errors.",
       caption="Public NAEP Data Service API. Differential change (p90 minus p10) reproduces the restricted-use Table 2 column (a) of the\ncompanion AERA Open article to the reported precision (within 0.05) in all six cells: 8.7, 7.0, 1.5, 7.9, 6.4, 4.5.") +
  theme_sim
ggsave(file.path(OUT,"fig9-qd-curves.png"), f9, width=11, height=6.4, dpi=200)
message("wrote ", file.path(OUT,"fig9-qd-curves.png"))

## ---- Figure 10: the targeting screen, and its degradation -----------------
if (is.null(tg_raw)) { message("no bottom-decile CSV; skipping Figure 10"); quit(save="no") }
## sim-bottom-decile.csv holds both the p10 and p25 decompositions
## (target_pct); Figure 10 is titled and captioned as the bottom DECILE, so it
## must filter to target_pct==10 or it silently mixes in the p25 rows.
## share_of_bottom_decile was this column's name before sim-bottom-decile.csv
## was restructured to carry both cuts; it is now share_of_tail.
tg <- tg_raw %>% filter(target_pct == 10) %>%
  transmute(cell, year, group, share=pop_share, tail=share_of_tail)
tg$cell <- factor(tg$cell, levels=ord)
ed <- tg %>% filter(grepl("^Econ", group))

f10 <- ggplot(ed, aes(factor(year), tail, group=cell)) +
  geom_col(aes(fill=factor(year)), width=0.62) +
  geom_text(aes(label=sprintf("%.0f%%", tail*100)), vjust=-0.5, size=3) +
  geom_hline(aes(yintercept=share), linetype="dashed", colour="grey30") +
  facet_wrap(~cell, nrow=2) +
  scale_fill_manual(values=c("2019"="#4393C3","2024"="#D6604D"), guide="none") +
  scale_y_continuous("Share of the bottom decile", labels=percent_format(accuracy=1),
                     limits=c(0,1)) +
  xlab(NULL) +
  labs(title="Economic disadvantage identifies most of the bottom decile, but the screen is weakening",
       subtitle="Bars: share of students below the 10th percentile who are economically disadvantaged.\nDashed line: that group's share of the whole population. The gap between them is the targeting lift.",
       caption="From each group's published NAEP score distribution (10-point bins) and percentiles; no tail is assumed.\nStudents whose economic status is not available take the remainder of the bottom decile. Public NAEP Data Service API.") +
  theme_sim
ggsave(file.path(OUT,"fig10-targeting-screen.png"), f10, width=11, height=6.4, dpi=200)
message("wrote ", file.path(OUT,"fig10-targeting-screen.png"))
