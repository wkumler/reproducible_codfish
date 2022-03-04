# Add R script details below
# Setup ----


# End with call to ggsave or png ----
ggsave(filename = "codfish_template.png", plot = gp, device = "png", 
       width = 8, height = 3, units = "in", dpi = 144, type="cairo")
