# Add R script details below
# Setup ----

library(tidyverse)
library(data.table)
library(cowplot)
library(magick)
library(ggnewscale)
library(maps)

# Pull down and clean chlorophyll data ----
mapdata <- fread("https://neo.gsfc.nasa.gov/servlet/RenderData?si=1849173&cs=rgb&format=CSV&width=3600&height=1800", header = FALSE)

# Convert from wide to long with melt()
# Specify lat/lon based on map resolution (0.1 degree)
# Remove mssing values (99999s)
# Set a cap on the maximum value to help log scaling look nicer
# Filter down to the region of interest (based on trial and error)
# Log10 scale the chlorophyll values so the colors look nice
chldata <- melt(mapdata) %>%
  .[,lat:=rep(seq(0.1, 180, 0.1), times=3600)*-1+90] %>%
  .[,lon:=rep(seq(0.1, 360, 0.1), each=1800)-180] %>%
  .[value<99999] %>%
  .[,value:=pmin(value, 10)] %>%
  .[lon%between%c(-80, 40)] %>%
  .[lat%between%c(-60, 0)] %>%
  .[,value:=log10(value)]

# External scale bars (I'm not proud of this) ----
# Create data frames for left, right, top, and bottom black/white scalebars
scalebar_lon_x <- data.frame(xmin=seq(-80, 40, 10)) %>%
  mutate(xmax=lead(xmin)) %>%
  drop_na() %>%
  as.data.frame() %>%
  mutate(fill=rep(c("black", "white"), times=6))
scalebar_lat_x <- data.frame(ymin=seq(-60, 0, 10)) %>%
  mutate(ymax=lead(ymin)) %>%
  drop_na() %>%
  as.data.frame() %>%
  mutate(fill=rep(c("black", "white"), times=3))
# Switch the order of "black" and "white" so we get nice alternation
scalebar_lon_y <- data.frame(xmin=seq(-80, 40, 10)) %>%
  mutate(xmax=lead(xmin)) %>%
  drop_na() %>%
  as.data.frame() %>%
  mutate(fill=rep(c("white", "black"), times=6))
scalebar_lat_y <- data.frame(ymin=seq(-60, 0, 10)) %>%
  mutate(ymax=lead(ymin)) %>%
  drop_na() %>%
  as.data.frame() %>%
  mutate(fill=rep(c("white", "black"), times=3))

# Base chlorophyll map ----
# Start with a raster map of the chlorphyll
# Use the viridis color scale
# Add white lines on the axis ticks
# Add the country borders with the geom_path
# Add the cruise segments manually with annotate("segment")
# Add the cruise labels with annotate("label")
# Establish a new colorscale for the black and white fill in the colorbars
# Add white rectangles to cover up data outside the selected range on top and right
#   (only became necessary when text size increased)
# Add the black and white bars (this part could have been optimized better, oof)
# Set them to be filled in with the prespecified "black" and "white"
# Crop to area of interest and specify 1:1 axis ratio with coord_fixed()
# Set breaks on the x and y axis and label them nicely
# Fiddle with theme parameters until it looks nice
base_map <- ggplot() +
  # Chlorophyll part
  geom_raster(aes(x=lon, y=lat, fill=value), data=chldata) +
  scale_fill_viridis_c() +
  geom_vline(xintercept = seq(-80, 40, 20), color="white") +
  geom_hline(yintercept = seq(-60, 0, 20), color="white") +
  annotate("label", x=40, y=-60, hjust=1, vjust=0, label="Data from neo.gsfc.nasa.gov",
           label.r=unit(0, "in"), size=15/.pt, fill="#FFFFFFAA", color="black") +
  # World map part
  geom_path(aes(x=long, y=lat, group=group), data=map_data("world")) +
  # Scale bar outline part
  ggnewscale::new_scale_fill() +
  annotate("rect", xmin=-Inf, xmax=Inf, ymin=1, ymax=Inf, color="white", fill="white") +
  annotate("rect", xmin=41, xmax=Inf, ymin=-Inf, ymax=Inf, color="white", fill="white") +
  geom_rect(aes(xmin=xmin, ymin=-60, xmax=xmax, ymax=-61, fill=fill), 
            data=scalebar_lon_x, color="black") +
  geom_rect(aes(xmin=xmin, ymin=0, xmax=xmax, ymax=1, fill=fill),
            data=scalebar_lon_y, color="black") +
  geom_rect(aes(xmin=-80, ymin=ymin, xmax=-81, ymax=ymax, fill=fill),
            data=scalebar_lat_y, color="black") +
  geom_rect(aes(xmin=40, ymin=ymin, xmax=41, ymax=ymax, fill=fill),
            data=scalebar_lat_x, color="black") +
  scale_fill_identity() +
  # Formatting nicely for export
  coord_fixed(xlim = c(-81, 45), ylim=c(-61, 2), expand = FALSE) +
  scale_x_continuous(breaks = seq(-80, 40, 20), 
                     labels = c("80°W", "60°W", "40°W", "20°W", "0°", "20°E", "40°E")) +
  scale_y_continuous(breaks = seq(-60, 0, 20),
                     labels = c("60°S", "40°S", "20°S", "0°")) +
  theme_void() +
  theme(axis.text = element_text(), legend.position = "none", 
        plot.background = element_rect(fill="white", color="white"),
        text = element_text(size=18))
ggsave("chlbasemap.png", plot = base_map, device = "png", width = 6, height = 3, dpi = 300, units = "in")

# Extract the legend and format it nicely ----
break_vals <- c(0.01, 0.03, 0.1, 0.3, 1, 3, 10)
break_labs <- c(0.01, 0.03, 0.1, 0.3, 1, 3, "10+")
leg_plot <- ggplot() +
  geom_raster(aes(x=lon, y=lat, fill=value), data=chldata) +
  scale_fill_viridis_c(breaks=log10(break_vals), labels=break_labs) +
  guides(fill=guide_colorbar(
    title = expression(paste("January 2023 chlorophyll ", italic("a"), " concentration (", paste(mg/m^3), ")")),
    title.position = "top", title.hjust = 0, ticks = TRUE,
    direction = "horizontal")) +
  theme(legend.position = "top", 
        legend.key.width = unit(1.1, "inches"),
        text = element_text(size=18),
        legend.title = element_text(vjust=-2),
        legend.text = element_text(vjust=2))
just_leg <- cowplot::get_legend(leg_plot)
ggsave("justlegend.png", plot = just_leg, device = "png", width = 6, height = 1, dpi = 300, units = "in", bg = "white")

# Image things
legend_image <- image_read("justlegend.png")
chlmap_image <- image_read("chlbasemap.png")
ecoregion_image <- image_read("https://ars.els-cdn.com/content/image/1-s2.0-S0967063717301437-gr4_lrg.jpg")
ecoregion_spacer <- image_blank(width = 90, height = 600, color = "white")

ecoregion_image_spaced <- ecoregion_image %>%
  image_crop("1190x600+1000+890") %>%
  image_border("black", geometry = "2x2") %>%
  image_border("white", "40x40") %>%
  c(ecoregion_spacer, .) %>%
  image_append() %>%
  image_scale("1800")

final_image <- image_append(
  c(legend_image, chlmap_image, ecoregion_image_spaced), stack = TRUE
) %>%
  image_trim() %>%
  image_border("white")

# End with call to ggsave or png ----
image_write(final_image, "ecoregion_chloromap.png", format = "png")
