
# Setup ----
library(tidyverse)
library(ggdark)
library(coin)
library(broom)

# filled_peaks <- read.csv("data/filled_peaks.csv")
# metadata_complete <- read.csv("data/metadata_complete.csv")
# clean_peaks <- filled_peaks %>%
#   left_join(metadata_complete %>% select(filename, samp_type, depth)) %>%
#   filter(samp_type=="Smp") %>%
#   filter(depth%in%c("DCM", "15m")) %>%
#   group_by(feature) %>%
#   mutate(rank_area=rank(M_area)) %>%
#   select(feature, filename, mz, rt, M_area, depth, rank_area)
# write.csv(clean_peaks, "data/clean_peaks.csv", row.names = FALSE)

clean_peaks <- read.csv("data/clean_peaks.csv")
feature_formulas <- read.csv("data/feature_formulas.csv")

# Data shaping ----

sig_peaks <- clean_peaks %>%
  nest(data=-feature) %>%
  # mutate(test=map(data, ~t.test(.x$M_area~.x$depth))) %>%
  mutate(test=map(data, ~wilcox.test(.x$rank_area~.x$depth))) %>%
  mutate(tidied=map(test, tidy)) %>%
  unnest(tidied) %>%
  select(feature, data, p.value, statistic) %>%
  filter(p.adjust(p.value, method = "fdr")<0.05)

# clean_peaks %>%
#   left_join(metadata_complete %>% select(filename, samp_type, depth)) %>%
#   filter(feature=="FT1172") %>%
#   ggplot() +
#   geom_boxplot(aes(x=depth, y=rank_area))

cn_ratios <- sig_peaks %>%
  left_join(feature_formulas) %>%
  filter(formula!="") %>%
  mutate(formula=str_replace(formula, "; .*", "")) %>%
  mutate(all_c=str_extract(formula, "C\\d*")) %>%
  mutate(all_c=case_when(
    is.na(all_c) ~ 0,
    all_c=="N" ~ 1,
    TRUE ~ as.numeric(str_extract(all_c, "\\d+"))
  )) %>%
  mutate(all_n=str_extract(formula, "N\\d*")) %>%
  mutate(all_n=case_when(
    is.na(all_n) ~ 0,
    all_n=="N" ~ 1,
    TRUE ~ as.numeric(str_extract(all_n, "\\d+"))
  )) %>%
  mutate(cn_ratio=all_c/all_n) %>%
  filter(is.finite(cn_ratio)) %>%
  ungroup() %>%
  mutate(highlow=statistic>mean(statistic)) %>%
  mutate(highlow=factor(highlow, levels = c(TRUE, FALSE), labels = c(
    "Abundant at surface", "Abundant at depth"
  )))

t.test(cn_ratio~highlow, data = cn_ratios)

set.seed(127)
pv <- pvalue(oneway_test(cn_ratio~highlow, data = cn_ratios, distribution=approximate(nresample = 9999)))

# Aaaaand plot ----

ggplot(cn_ratios, aes(x=highlow, y=cn_ratio, group=highlow)) +
  geom_violin(size=2, color="grey50") +
  geom_boxplot(width=0.1, size=2, color="grey80", fatten=5) +
  geom_jitter(width = 0.2, height = 0, aes(color=highlow), size=3) +
  scale_color_manual(breaks = c("Abundant at surface", "Abundant at depth"),
                     values = c("#638800", "#0078BA")) +
  dark_theme_void() +
  ylim(-1.5, NA) +
  expand_limits(x=0) + 
  expand_limits(x=3) + 
  theme(legend.position = "none", 
        panel.background = element_rect(fill = "transparent", color=NA),
        plot.background = element_rect(fill = "transparent", color=NA)) +
  annotate("text", x=c(0.9, 2.1), y=-0.2,
           label=c("Abundant at surface", "Abundant at depth"),
           size=6, color=c("#638800", "#0078BA"), angle=15) +
  annotate("text", x=0.5, y=7, label="Carbon:Nitrogen ratio", 
           size=6, label.size=NA, color="grey80", angle=90) +
  annotate("text", x=1.55, y=7, label=paste0("p-value:\n", round(pv, digits = 5)),
           size=4)


# End with call to ggsave or png ----
ggsave("depth_cn_boxplots.png", device = "png", type="cairo", 
       width = 4, height = 6, units = "in", dpi = 144, 
       # bg = "transparent", #transparent doesn't render well on GitHub
       bg = "black")
