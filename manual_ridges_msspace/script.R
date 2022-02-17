library(tidyverse)
library(RaMS)
library(fuzzyjoin)
library(ggdark)

mz_group <- function(mz_vals, ppm){
  group_vec <- numeric(length(mz_vals))
  group_num <- 1L
  init_vec <- mz_vals
  names(init_vec) <- seq_along(init_vec)
  while(length(init_vec)>0){
    mz_i <- init_vec[1]
    err <- mz_i*ppm/1000000
    mz_idxs <- init_vec>mz_i-err & init_vec<mz_i+err
    group_vec[as.numeric(names(mz_idxs)[mz_idxs])] <- group_num
    init_vec <- init_vec[!mz_idxs]
    group_num <- group_num+1L
  }
  group_vec
}

msdata <- grabMSdata("data/180205_Poo_TruePoo_Full2_mini.mzML.gz")

cmpd_data <- msdata$MS1 %>%
  arrange(desc(int)) %>%
  mutate(mz_group=mz_group(mz, ppm = 50))

standard_list <- read.csv(paste0("https://raw.githubusercontent.com/",
                                 "IngallsLabUW/Ingalls_Standards/",
                                 "b30fd368346096d63c61c9dc929c814bf5f5b180/",
                                 "Ingalls_Lab_Standards.csv")) %>%
  filter(Column=="HILIC" & Liquid_Fraction=="Aq" & z>0) %>%
  select(compound_name=Compound_Name, mz)

trace_names <- cmpd_data  %>%
  group_by(mz_group) %>%
  summarise(mz=mean(mz), maxint=max(int)) %>%
  difference_left_join(standard_list, max_dist = 0.001) %>%
  group_by(mz_group) %>%
  summarise(compound_name=paste(compound_name, collapse = "\n"),
            mz=mean(mz.x)) %>%
  filter(mz_group>0) %>%
  mutate(compound_name = ifelse(compound_name=="NA", "Unknown", compound_name))

color_scale <- trace_names %>%
  distinct(compound_name) %>%
  arrange(compound_name) %>%
  mutate(manual_color=c(hcl(h = seq(15, 375, length = 10), l = 65, c = 100)[1:9], "grey50"))

cmpd_data %>%
  filter(rt%between%c(4, 12)) %>%
  left_join(trace_names, by="mz_group") %>%
  select(mz=mz.y, rt, int, compound_name, mz_group) %>%
  arrange(rt) %>%
  filter(mz_group<=20) %>%
  group_by(mz_group) %>%
  group_split() %>%
  map_dfr(function(x){
    rbind(
      data.frame(mz=mean(x$mz), rt=min(x$rt), int=0, 
                 compound_name=unique(x$compound_name),
                 mz_group=unique(x$mz_group)),
      x,
      data.frame(mz=mean(x$mz), rt=max(x$rt), int=0, 
                 compound_name=unique(x$compound_name),
                 mz_group=unique(x$mz_group))
    )
  }) %>%
  group_by(mz_group) %>%
  mutate(int = int/max(int)) %>%
  mutate(height=mz+int*10*(21-mz_group)/4) %>%
  ungroup() %>%
  mutate(mz=factor(mz, levels = unique(
    as.character(sort(as.numeric(mz), decreasing = TRUE)))
    )) %>%
  ggplot() +
  geom_polygon(aes(x=rt, y=height, group=mz, fill=compound_name), 
               color="black", lwd=0.25) +
  scale_fill_manual(limits=color_scale$compound_name, 
                    values = color_scale$manual_color,
                    name=NULL) +
  theme_bw() +
  xlab("Retention time (min)") +
  ylab(expression(paste(italic("m/z"), " ratio")))

ggsave(filename = "manual_ridge_vis.png", device = "png", type="cairo",
       width = 8, height = 3, units = "in", dpi = 144)
