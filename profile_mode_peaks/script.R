library(tidyverse)
library(RaMS)

msdata <- grabMSdata("data/200605_Smp_GBTFate1MT0-pos_A_mini.tmzML")

msdata$MS1[mz%between%c(118.07, 118.10)] %>%
  filter(rt%between%c(7.5, 8.5)) %>%
  ggplot() +
  geom_point(aes(x=mz, y=int, color=log10(int)), alpha=0.5) +
  coord_cartesian(ylim = c(0, 1e6)) +
  scale_color_viridis_c() +
  theme_minimal() +
  theme(legend.position="none") +
  xlab(expression(paste(italic("m/z"), " ratio"))) +
  ylab("Intensity") +
  annotate(geom = "segment", 
           x=c(118.077, 118.077, 118.095, 118.095, 118.083),
           y=c(600000, 600000, 700000, 700000, 900000), 
           xend = c(118.076, 118.078, 118.094, 118.096, 118.084),
           yend = c(500000, 200000, 200000, 500000, Inf),
           arrow=arrow(ends = "last", length = unit(0.02, "npc"), type = "closed")) +
  annotate(geom = "label", x=c(118.077, 118.095), y=c(600000, 700000), 
           label="Mystery peaks") +
  annotate(geom = "label", y=900000, x=118.083, label="Betaine")
ggsave(filename = "betaine_horns.png", device = "png", type="cairo",
       width = 8, height = 4, units = "in")
