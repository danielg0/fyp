library(tidyverse)
library(ggthemes)

library(showtext)
font.add("Latin Modern Roman", "/usr/share/fonts/OTF/lmroman10-regular.otf")
showtext.auto()

data <- read_csv("data.csv")

interval_vs_time <- ggplot(data, aes(x = interval, y = cpu_time)) +
	geom_point() + geom_line() +
	scale_y_continuous(label = scales::label_timespan(),
			   lim = c(0, NA), breaks = c(0, 1800, 3600, 5400, 7200)) +
	scale_x_continuous(label = scales::label_comma()) +
	labs(y = "CPU User Time", x = "Interval Width (instructions)") +
	theme_few(base_family="Latin Modern Roman", base_size=10) + scale_color_few()

ggsave("plots/cpu_user_time_vs_interval_width.svg", width=15, height=5, unit="cm")
