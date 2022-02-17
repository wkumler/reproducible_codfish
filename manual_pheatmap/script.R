library(tidyverse)
library(ggnewscale)

set.seed(123)

peak_data <- read.csv("data/norm_peaks.csv")
metadata <- read.csv("data/metadata_complete.csv")

transect_df <- peak_data %>%
  left_join(metadata) %>%
  filter(samp_type=="Smp") %>%
  mutate(depth=factor(depth, levels=c("175m", "DCM", "15m"))) %>%
  arrange(depth) %>%
  mutate(filename=factor(filename, levels=unique(filename))) %>%
  select(feature, filename, norm_area) %>%
  group_by(feature) %>%
  mutate(norm_area=rank(norm_area))

cmpd_hclust <- transect_df %>%
  pivot_wider(names_from=feature, values_from = norm_area) %>%
  column_to_rownames("filename") %>%
  as.matrix() %>%
  t() %>%
  dist(method = "manhattan") %>%
  hclust(method = "average")

cmpd_kmeans <- transect_df %>%
  pivot_wider(names_from=feature, values_from = norm_area) %>%
  column_to_rownames("filename") %>%
  as.matrix() %>%
  t() %>%
  kmeans(centers = 5)
kmeans_df <- data.frame(feature=names(cmpd_kmeans$cluster)) %>%
  mutate(cluster=factor(cmpd_kmeans$cluster)) %>%
  mutate(feature=factor(feature, levels = with(cmpd_hclust, labels[order])))

transect_df %>%
  mutate(feature=factor(feature, levels = with(cmpd_hclust, labels[order]))) %>%
  ggplot() + 
  geom_raster(aes(x=feature, y=filename, fill=norm_area)) +
  scale_fill_gradient2(low = "steelblue", mid = "grey90", 
                       high = "goldenrod1", midpoint = 49.5,
                       breaks=c(1, 50, 99), labels=c(
                         "Very little of a given compound", 
                         "Median compound abundance", 
                         "Compound maximum"
                       ), name="") +
  new_scale_fill() +
  geom_tile(aes(x=feature, y=-1.5, fill=cluster), height=3, data = kmeans_df) +
  scale_fill_discrete(guide="none") +
  theme_void() +
  theme(legend.position = "top", 
        legend.key.width = unit(dev.size()[1] / 6, "inches"),
        legend.text = element_text(size=8)) +
  coord_cartesian(ylim=c(-15, NA)) +
  annotate("rect", xmin=-20, xmax=0, ymin=c(0, 33, 66), ymax=c(33, 66, 100), 
           fill=c("#0d374f", "#367776", "#1f92d0")) +
  annotate("text", x = -11, y=c(16.5, 49.5, 82.5), label=c("175m", "DCM", "15m"),
           angle=90, color="white", size=6) +
  annotate("text", x=205, y=-10, label="Metabolite", size=6) +
  annotate("text", x=Inf, y=-10, label="k-means clusters with n=5", hjust=1) +
  annotate("tile", x=312, y=seq(-8, -13, length.out=5), width=10, height=2,
           fill=hcl(h = seq(15, 375, length = 6), l = 65, c = 100)[1:5])

ggsave(filename = "ggplot_heatmap.png", device = "png", type="cairo",
       width = 8, height = 4, units = "in", dpi = 144)
