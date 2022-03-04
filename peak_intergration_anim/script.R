library(tidyverse)
library(gganimate)

peak_shape <- dbeta(seq(0, 1, length.out=50), shape1 = 10, shape2 = 8)
peak_shape <- peak_shape/max(peak_shape)

multipeak_eic <- data.frame(
  int=rep(peak_shape, 6),
  rt=seq(1:50),
  samptype=gl(2, k = 150, labels = c("15m", "DCM"))
) %>%
  mutate(filename=gl(6, k = 50, labels = paste(
    c("15m", "DCM"), rep(rep(LETTERS[1:3], each=3), 2)
    ))) %>%
  mutate(int=int*10*(as.numeric(samptype)-1)+runif(50*6))



ggplot(multipeak_eic) +
  geom_line(aes(x=rt, y=int)) +
  facet_wrap(~filename)
