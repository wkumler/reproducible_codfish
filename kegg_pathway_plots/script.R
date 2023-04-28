# Add R script details below
# Setup ----
library(tidyverse)
library(httr)
library(xml2)
library(KEGGREST)

pathway_id <- "ko00430"
# You don't actually need the masses for this demo but I like having a reference
# for the functionality here
pathway_masses <- keggGet(pathway_id)[[1]]$COMPOUND %>%
  # Loop over cmpds 10 at a time because KEGG doesn't provide more
  split(rep(1:ceiling(length(.)/10), length.out=length(.))) %>%
  map(function(kegg_ids){
    keggout <- keggGet(names(kegg_ids))
    keggmasses <- as.numeric(sapply(keggout, function(x){
      em <- x$EXACT_MASS
      ifelse(is.null(em), NA, em)
    }))
    data.frame(kegg_id=names(kegg_ids), cmpd_name=kegg_ids, mass=keggmasses)
  }) %>%
  bind_rows()

pathway_image <- paste0("https://rest.kegg.jp/get/", pathway_id, "/image") %>%
  GET() %>%
  content() %>%
  as.raster()
base_gp <- expand_grid(
  y=rev(seq_len(nrow(pathway_image))),
  x=seq_len(ncol(pathway_image))
) %>%
  mutate(pixel_color=as.character(pathway_image)) %>%
  ungroup() %>%
  ggplot() +
  geom_raster(aes(x=x, y=y, fill=pixel_color)) +
  scale_fill_identity() +
  theme_void() +
  coord_fixed()

# KEGGREST doesn't return the pathway image info so we have to request those
# manually with xml2's GET() and content()
pathway_xml <- paste0("https://rest.kegg.jp/get/", pathway_id, "/kgml") %>%
  GET() %>%
  content()
getGraphics <- function(entry_type){
  xpression <- paste0("//entry[@type='", entry_type, "']")
  given_xml <- xml_find_all(pathway_xml, xpath = xpression)
  given_data <- as.data.frame(do.call(rbind, xml_attrs(given_xml)))
  given_graphics <- given_xml %>%
    xml_find_all("graphics") %>%
    xml_attrs() %>%
    do.call(what=rbind) %>%
    as.data.frame() %>%
    select(x, y, width, height) %>%
    mutate(across(everything(), as.numeric)) %>%
    mutate(y=-y+nrow(pathway_image)) %>%
    mutate(x=x+2)
  cbind(given_data, given_graphics)
}
set.seed(123)
cmpd_entries <- getGraphics("compound") %>%
  mutate(value=rnorm(n()))
rxn_entries <- getGraphics("ortholog") %>%
  mutate(value=rnorm(n())) %>%
  mutate(name=str_remove(name, "ko:")) %>%
  separate_rows(name, sep = " ko:")

gp <- base_gp +
  geom_point(aes(x=x, y=y, color=value), size=3, data=cmpd_entries) +
  geom_tile(aes(x=x, y=y, width=width+2, height=height+2), 
            data=rxn_entries, fill="white") +
  geom_label(aes(x=x, y=y, label=name, color=value), 
             data=rxn_entries, size=3) +
  scale_color_gradient2(mid = "grey80") +
  theme(plot.background = element_rect(color=NA, fill="white"),
        legend.position = c(0.75, 0.75), legend.direction = "horizontal")


# End with call to ggsave or png ----
ggsave(filename = "kegg_pathway_plot.png", plot = gp, device = "png", 
       width = 8, height = 6, units = "in", dpi = 200)
