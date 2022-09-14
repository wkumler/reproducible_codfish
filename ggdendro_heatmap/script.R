# Add R script details below

library(tidyverse)
library(ggdendroplot)

heatmap_cor <- read_csv("data/filled_file_metadata.csv") %>%
  filter(samp_type=="Smp") %>%
  filter(cruise=="MT") %>%
  select(abs_depth, time, lat, sla, local_hour, 
         ends_with("abund"), ends_with("um"), ends_with("ug")) %>%
  data.matrix() %>%
  cor(use = "pair")

coph_coef <- cor(cophenetic(hclust(dist(heatmap_cor))), dist(heatmap_cor))
# pheatmap::pheatmap(
#   mat = heatmap_cor, color = viridisLite::viridis(100),border_color = "grey80"
# )

factor_levels <- c(
  "no23_um", "po4_um", "si_um", "PC_um", "PN_um", "DON_um", "DOP_um", "oxy_um",
  "chl_ug", "phaeo_ug", "dic", "ph", "theta",
  paste0(c("pro", "syn", "euk", "het"), "_abund"), "beam_atten"
)
factor_labels <- c(
  "Nitrate + nitrite", "Phosphate", "Silicate", "Particulate C", "Particulate N",
  "Dissolved organic N", "Dissolved organic P", "Oxygen", "Chlorophyll a",
  "Phaeophytin", "Dissolved inorganic C", "pH", "Density",
  paste(c("Pro.", "Syn.", "Picoeuk.", 
          "Het. bact."), "abundance"),
  "Beam attenuation"
)

heatmap_labels <- c(factor_labels, "Depth", "Time", "Latitude", "Sea level anomaly", "Local hour")
heatmap_levels <- c(factor_levels, "abs_depth", "time", "lat", "sla", "local_hour")
names(heatmap_labels) <- heatmap_levels

hc <- hclust(dist(t(heatmap_cor)))
hclust_labels <- heatmap_labels[hc$labels[hc$order]]

ggcor_df <- heatmap_cor %>%
  as.data.frame() %>%
  rownames_to_column("x") %>%
  pivot_longer(!x, names_to = "y") %>%
  # mutate(x=factor(x, levels = heatmap_levels, labels = heatmap_labels)) %>%
  # mutate(y=factor(y, levels = heatmap_levels, labels = heatmap_labels)) %>%
  mutate(x=factor(x, levels = names(hclust_labels), labels = hclust_labels)) %>%
  mutate(y=factor(y, levels = names(hclust_labels), labels = hclust_labels)) %>%
  arrange(x, y) %>%
  filter(as.numeric(x)<=as.numeric(y))
ggcor_labs <- ggcor_df %>% distinct(x) %>% mutate(y=row_number()-0.8)

gp <- ggplot() +
  geom_tile(aes(x=as.numeric(x), y=as.numeric(y), fill=value), data = ggcor_df) +
  geom_text(aes(x=as.numeric(x), y=as.numeric(y), label=x), data = ggcor_labs,
            angle=90, hjust=1, size=12*0.8/ggplot2::.pt) +
  geom_text(aes(x=0, y=as.numeric(y)+1, label=x), data = ggcor_labs,
            hjust=1, size=12*0.8/ggplot2::.pt) +
  geom_dendro(hc, ylim=c(19.5, 22), lwd=1) +
  annotate("text", x=Inf, y=Inf, label=paste("Coph coef:", round(coph_coef, 3)), 
           hjust=1, vjust=1) +
  scale_fill_gradient2(limits=c(-1, 1), name="Pearson's\ncorrelation\ncoefficient") +
  scale_x_discrete(position = "top") +
  theme_minimal() +
  theme(axis.title = element_blank(),
        legend.position = c(0.9, 0.3),
        axis.text = element_blank(),
        panel.grid = element_blank()) +
  coord_fixed() +
  scale_y_continuous(limits = c(-3, 22)) +
  scale_x_continuous(limits = c(-7, 21))
gp

# End with call to ggsave or png ----
ggsave(filename = "ggdendro_heatmap.png", plot = gp, device = "png", 
       width = 8, height = 5, units = "in", dpi = 144, type="cairo", bg = "white")
