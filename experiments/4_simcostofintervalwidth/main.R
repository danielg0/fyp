library(tidyverse)
library(ggthemes)

data <- read_csv("data.csv")

interval_vs_time <- ggplot(data, aes(x = interval, y = cpu_time)) +
	geom_point() + geom_line() +
	scale_y_continuous(label = scales::label_timespan(),
			   lim = c(0, NA), breaks = c(1800, 3600, 5400, 7200)) +
	scale_x_continuous(label = scales::label_comma()) +
	labs(y = "CPU User Time", x = "Interval Width (instructions)") +
	theme_few() + theme_few() + scale_color_few()

ggsave("plots/cpu_user_time_vs_interval_width.svg", width=10, height=5)
