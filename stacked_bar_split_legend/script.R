# Add R script details below
# Setup ----
library(tidyverse)

samp_concs <- read_csv("data/clean_complete.csv")
parametadata <- read_csv("data/parametadata.csv")

# Define splividis (split viridis)
splividis <- function(n, ...){
  vir <- viridis::viridis(n, ...)
  if(n%%2==0){
    vir[as.numeric(matrix(1:n, ncol=2, byrow = TRUE))]
  } else {
    index_vec <- suppressWarnings(as.numeric(matrix(1:n, ncol=2, byrow = TRUE)))
    vir[head(index_vec, -1)]
  }
}

# Define new key_glyph
# Has to handle the colored legend separately from the alpha legend
# otherwise the alpha legend also gets split
draw_key_splitrect <- function(data, params, size) {
  # We pass the data$note="custom" along to the legend 
  # using override.aes so it knows when to split
  if(!is.null(data$note) && data$note=="custom"){
    # Stolen directly from draw_key_rect
    grid::rectGrob(gp = grid::gpar(
      col = NA, 
      fill = fill_alpha(data$fill %||% data$colour %||% "grey20", data$alpha), 
      lty = data$linetype %||% 1)
    )
  } else {
    grid::grobTree(
      # Plot the top one (will have to manually edit this if additional alphas are used)
      grid::rectGrob(
        y = unit(0.75, "npc"), height = unit(0.5, "npc"),
        gp = grid::gpar(fill = alpha(data$fill, 0.5), col = NA)
      ),
      # Plot the bottom one
      grid::rectGrob(
        y = unit(0.25, "npc"), height = unit(0.5, "npc"),
        gp = grid::gpar(fill = data$fill, col = NA)
      ),
      # Add a white border around the legend to give the keys some separation
      grid::rectGrob(
        width = unit(1, "npc"), height = unit(1, "npc"),
        gp = grid::gpar(fill = NA, col = "white", lwd = 1)
      )
    )
  }
}

# Plot the data in a nice order
top_cmpds <- samp_concs %>%
  mutate(compound_name=str_remove_all(compound_name, "^L-")) %>%
  mutate(compound_name=str_remove(compound_name, "/beta-Glutamic acid")) %>%
  summarise(total_nm=sum(conc_nm_in_env, na.rm=TRUE), .by=compound_name) %>%
  filter(total_nm>0) %>%
  arrange(desc(total_nm)) %>%
  slice(1:14) %>%
  pull(compound_name)

samp_concs %>%
  mutate(compound_name=str_remove_all(compound_name, "^L-")) %>%
  mutate(compound_name=str_remove(compound_name, "/beta-Glutamic acid")) %>%
  mutate(lab_stat=ifelse(str_detect(iso_name, "13C0, 15N0"), "Unlabeled", "Labeled")) %>%
  summarise(conc_nm=sum(conc_nm_in_env, na.rm=TRUE), .by=c(compound_name, lab_stat, shortname)) %>%
  mutate(compound_name=ifelse(compound_name%in%top_cmpds, compound_name, "Other")) %>%
  summarise(total_nm=sum(conc_nm), .by=c(compound_name, lab_stat, shortname)) %>%
  mutate(compound_name=factor(compound_name, levels=c(top_cmpds, "Other"))) %>%
  left_join(parametadata %>% distinct(shortname, amendment, depth, startime, timepoint, tripl),
            by = join_by(shortname)) %>%
  group_by(compound_name, lab_stat, amendment, depth, timepoint) %>%
  summarise(mean_nm=mean(total_nm)) %>%
  ungroup() %>%
  ggplot() +
  geom_col(aes(x=timepoint, y=mean_nm, fill=compound_name, alpha=lab_stat), color="black", 
           linewidth=0.2, key_glyph=draw_key_splitrect) +
  facet_grid(depth~amendment, scales="free_x") +
  scale_fill_manual(breaks=c(top_cmpds, "Other"), values = c(splividis(14), "grey50")) +
  scale_alpha_manual(breaks=c("Labeled", "Unlabeled"), values = c(0.5, 1)) +
  theme_bw() +
  guides(alpha=guide_legend(override.aes = list(note="custom")))

# End with call to ggsave or png ----
ggsave(filename = "stacked_bar_split_legend.png", device = "png", 
       width = 8, height = 5, units = "in", dpi = 144)
