
library(tidyverse)
library(vegan)


# norm_peaks contains integrated peak areas across many files for many features
norm_peaks <- read.csv("data/norm_peaks.csv")
# metadata contains sample depth and corresponding file name
metadata <- read.csv("data/metadata_complete.csv")

# Select only proper "samples", leaving out blanks and standards
clean_df <- norm_peaks %>%
  left_join(metadata) %>%
  filter(samp_type=="Smp") %>%
  select(feature, norm_area, filename, depth)

# Convert to matrix in wide format
clean_mat <- clean_df %>%
  select(feature, norm_area, filename) %>%
  pivot_wider(values_from = norm_area, names_from = feature) %>%
  column_to_rownames("filename")

# Normalize
normalized_mat <- scale(clean_mat)

# Perform NMDS
nmds_output <- metaMDS(clean_mat, distance = "euclidean", k=2)

# Convert vegan output to familiar data frame
nmds_df <- nmds_output$points %>%
  as.data.frame() %>%
  rownames_to_column("filename") %>%
  left_join(metadata) %>%
  select(filename, starts_with("MDS"), depth) %>%
  mutate(basename=str_extract(filename, "MS\\d+C\\d+.*(?=_[A-C])"))

nmds_labels <- nmds_df %>%
  group_by(depth) %>%
  summarise(MDS1=mean(MDS1), MDS2=mean(MDS2))

# Plot
gp <- ggplot(nmds_df, aes(x=MDS1, y=MDS2)) +
  geom_polygon(aes(fill=depth, group=basename), alpha=0.5) +
  geom_polygon(aes(color=depth, group=basename), fill=NA) +
  theme_minimal() +
  theme(legend.position="none") +
  geom_label(data = nmds_labels, aes(color=depth, label=depth), 
             size=6, nudge_y = 0.01)
gp

# Save with fixed parameters
ggsave(filename = "nmds_shardplot.png", plot = gp, device = "png", 
       width = 8, height = 3, units = "in", dpi = 144, type="cairo")
