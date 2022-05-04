
# Setup ----
library(tidyverse)
library(ggrepel)

pcn_data <- read.csv("falkor_pcn_data.csv")
metab_data <- data.frame(
  station=c(32, 34, 47, 50),
  depth=c(rep(25, 4), 98, 115, 125, 120)
)

# Interpolation function ----
idwInterp2D <- function(known_pts, unknown_pts=NULL){
  if(is.null(unknown_pts)){
    unknown_pts <- expand.grid(
      seq(min(known_pts[,1]), max(known_pts[,1]), length.out=100),
      seq(min(known_pts[,2]), max(known_pts[,2]), length.out=100)
    )
    unknown_pts <- setNames(unknown_pts, names(known_pts)[1:2])
  }
  
  unknown_pts[,names(known_pts)[3]] <- sapply(1:nrow(unknown_pts), function(i){
    x_i <- unknown_pts[i,names(known_pts)[1],drop=TRUE]
    x_all <- known_pts[,names(known_pts)[1],drop=TRUE]
    y_i <- unknown_pts[i,names(known_pts)[2],drop=TRUE]
    y_all <- known_pts[,names(known_pts)[2],drop=TRUE]
    dists <- sqrt((x_i-x_all)^2 + (y_i-y_all)^2)
    weighted.mean(known_pts[,names(known_pts)[3],drop=TRUE], 1/(dists^2))
  })
  unknown_pts
}

# Interpolation ----
interped_metabs <- pcn_data %>%
  select(station, depth, PC_um) %>%
  idwInterp2D(unknown_pts = metab_data)

gpinterp <- pcn_data %>%
  idwInterp2D() %>%
  ggplot(aes(x=station, y=depth)) +
  geom_raster(aes(fill=PC_um)) +
  geom_point(data = pcn_data, color="grey80") +
  geom_point(data = interped_metabs) +
  geom_label_repel(data = interped_metabs, aes(label=round(PC_um, 2)), min.segment.length = 0) +
  scale_y_reverse() +
  scale_fill_viridis_c() +
  labs(x="Station number", fill="Particulate\ncarbon\n(uM)") +
  theme_minimal() +
  theme(axis.title.y = element_blank(), axis.text.y = element_blank())
gpdepthpro <- pcn_data %>%
  mutate(station=paste("St.", station)) %>%
  mutate(station=factor(station, levels=unique(station))) %>%
  ggplot(aes(x=PC_um, y=depth, color=factor(station))) + 
  geom_point() + 
  geom_path() + 
  scale_y_reverse() +
  theme_minimal() +
  theme(legend.title = element_blank(), legend.position = "left") +
  labs(x="Particulate carbon (uM)", y="Depth") +
  xlim(0, NA)
gp <- gridExtra::grid.arrange(gpdepthpro, gpinterp, nrow=1)

# End with call to ggsave or png ----
ggsave(filename = "interp_2d_iwd.png", plot = gp, device = "png",
       width = 8, height = 3, units = "in", dpi = 144, type="cairo")
