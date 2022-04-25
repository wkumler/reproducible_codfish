
# Setup ----
library(tidyverse)
library(ggdark)
# devtools::install_github("https://github.com/IngallsLabUW/ggbarribbon")
library(ggbarribbon)


diss_data <- read.csv("data/CX_EnviroConc_supptable6.csv") %>%
  select(compound_name = Compound, location=Sample, 
         avg_nm=Mean.Concentration..nM.) %>%
  mutate(location=toupper(location))
part_data <- read.csv("data/Heal_G1_data.csv") %>%
  select(compound_name=Compound.name.fig, ALOHA, NP) %>%
  pivot_longer(cols = c(ALOHA, NP), names_to = "location", values_to = "avg_nm")

# Data shaping ----

comb_data <- inner_join(diss_data, part_data, by=c("compound_name", "location"), 
                        suffix=c("_diss", "_part")) %>%
  filter(location=="ALOHA") %>%
  pivot_longer(cols = c(avg_nm_diss, avg_nm_part), names_to = "samp_type", 
               values_to = "avg_nm")  %>%
  mutate(samp_type=case_when(
    samp_type=="avg_nm_diss" ~ "Dissolved",
    samp_type=="avg_nm_part" ~ "Particulate"
  )) %>%
  group_by(samp_type) %>%
  mutate(rel_nm=avg_nm/sum(avg_nm))

# Basic plot with ALL compounds ----

comb_data %>%
  ungroup() %>%
  mutate(samp_type=as.numeric(factor(samp_type))*100) %>%
  ggplot(aes(x=samp_type, y=rel_nm, fill=compound_name)) +
  geom_bar_ribbon(interp_res = 1, color="black") +
  scale_x_continuous(breaks = c(100, 200), labels = c("Dissolved", "Particulate")) +
  scale_y_continuous(labels = scales::label_percent()) +
  coord_flip() +
  dark_theme_void() +
  theme(axis.text.y = element_text(),
        legend.position = "top",
        axis.text.x = element_text()
  )

# Cutting down to just top few compounds ----

top5_cmpds <- comb_data %>%
  group_by(compound_name) %>%
  summarize(mean_nm=mean(rel_nm)) %>%
  arrange(desc(mean_nm)) %>%
  slice(1:8) %>%
  pull(compound_name)

plot_data <- comb_data %>%
  mutate(compound_name=ifelse(
    compound_name%in%top5_cmpds, compound_name, "Other")
  ) %>%
  group_by(compound_name, samp_type) %>%
  summarize(total_nm=sum(avg_nm)) %>%
  group_by(samp_type) %>%
  mutate(rel_nm=total_nm/sum(total_nm)) %>%
  ungroup() %>%
  mutate(samp_type=as.numeric(factor(samp_type))*100) %>%
  mutate(compound_name=factor(compound_name, levels = c(top5_cmpds, "Other")))

other_colors <- c(hcl(h = seq(15, 375, length = length(top5_cmpds)+1), 
                      l = 65, c = 100)[1:length(top5_cmpds)], "grey50")
other_colors <- c(tail(hcl.colors(length(top5_cmpds)+1, palette = "plasma"), -1), "grey50")

anno_df <- tribble(
  ~compound_name, ~x, ~y,
  "Homarine", 0.2, 0.25,
  "Glutamic acid", 0.8, 0.3,
  "4-Hydroxyisoleucine", 0.75, 0.5,
  "Alanine", 0.2, 0.58,
  "DMSP", 0.8, 0.67,
  "Serine", 0.2, 0.7,
  "Aspartic acid", 0.2, 0.78,
  "Guanine", 0.8, 0.82,
  "Other", 0.5, 0.92
) %>%
  mutate(hx=ifelse(x>0.5, 1, 0)) %>%
  mutate(hx=ifelse(compound_name=="Other", 0.5, hx)) %>%
  mutate(x=ifelse(x>0.5, 0.95, 0.05)) %>%
  mutate(x=ifelse(compound_name=="Other", 0.5, x)) %>%
  mutate(anno_lab=ifelse(x>0.5, paste0(" ", compound_name), paste0(compound_name, " "))) %>%
  mutate(anno_lab=ifelse(compound_name=="4-Hydroxyisoleucine", " 4-Hydroxy-\nisoleucine", anno_lab)) %>%
  mutate(anno_lab=ifelse(compound_name=="Other", compound_name, anno_lab)) %>%
  mutate(x=x*100+100)

# Plotting just those few compounds ----

ggplot() +
  geom_bar_ribbon(aes(x=samp_type, y=rel_nm, fill=compound_name), 
                  plot_data, interp_res = 1, color="black") +
  scale_y_continuous(labels = scales::label_percent()) +
  theme_minimal() +
  theme(legend.position = "none", 
        panel.background = element_rect(fill = "black", color=NA),
        plot.background = element_rect(fill = "black", color=NA),
        axis.title.x = element_blank(),
        axis.ticks.x = element_blank(),
        axis.text.x = element_blank(),
        axis.title.y = element_blank(),
        axis.text.y = element_text(color="white"),
        plot.margin = margin(),
        panel.grid = element_line(color = "grey50"),
        panel.grid.major.x = element_blank(),
        panel.grid.minor.x = element_blank()) +
  scale_fill_manual(values = other_colors, breaks = c(top5_cmpds, "Other")) +
  scale_color_manual(values = other_colors, breaks = c(top5_cmpds, "Other")) +
  geom_label(aes(x=x, y=y, label=anno_lab, color=compound_name, hjust=hx),
             data = anno_df, size=6, lineheight = .8) +
  annotate("text", x=c(100, 200), y=-0.05, label = c("Dissolved", "Particulate"), 
           hjust=c(0, 1), size=8)

# End with call to ggsave or png ----
ggsave(filename = "diss_part_allu.png", device = "png", 
       type="cairo", width = 4, height = 6, units = "in", dpi = 144,
       bg="black")
       # bg="transparent") # Transparent doesn't show up well on GitHub gallery
