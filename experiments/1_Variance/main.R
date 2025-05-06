library(tidyverse)
library(ggthemes)

data <- read_csv("results/data.csv")
variance <- (data %>% group_by(benchmark, interval, cluster) %>% summarise(cpi_var = var(cpi), len = length(cpi)))
mean_variance <- (variance %>% group_by(interval) %>% summarise(mean = mean(cpi_var, na.rm = TRUE)))

variance_by_interval <- ggplot(variance, aes(x = as.factor(interval), y = cpi_var)) +
	geom_violin(scale = "width") + geom_jitter(alpha=0.25) +
#	geom_smooth(se = FALSE) +
#	geom_line(data = mean_variance, aes(x = interval, y = mean), color = "blue") +
#	scale_x_continuous(transform = "log2", breaks = seq(1000, 32000, by=1000),
#		labels = c("1000", "2000", "", "4000", rep("", 3), "8000", rep("", 7), "16000", rep("", 15), "32000")) +
	labs(x = "Interval Size (instructions)", y = "Variance of Cluster Point's CPI") +
	theme_few() + scale_colour_few()

ggsave("plots/variance_by_interval.svg", width=10, height=5)
