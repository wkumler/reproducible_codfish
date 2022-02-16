
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

# Plot
gp <- ggplot(nmds_df) +
  geom_polygon(aes(x=MDS1, y=MDS2, fill=depth, group=basename), 
               color="black", alpha=0.5) +
  theme_minimal()
gp

# Save with fixed parameters
ggsave(filename = "nmds_shardplot.png", plot = gp, device = "png", 
       width = 6.5, height = 3.5, units = "in", dpi = 72, type="cairo")
