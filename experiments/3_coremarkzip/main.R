library(tidyverse)
library(scales)
library(ggthemes)

data <- read_csv("results/results.csv")
variance <- (data %>% group_by(benchmark, interval, cluster) %>% summarise(cpi_var = var(cpi), len = length(cpi), ipc_var = var(ipc), cpi_sd = sd(cpi), ipc_sd = sd(ipc)))
mean_variance <- (variance %>% group_by(interval) %>% summarise(mean = mean(cpi_var, na.rm = TRUE)))

# be AWARE of the filter occurring here
variance_by_interval <- ggplot(filter(variance, len == 10), aes(x = 0, y = ipc_var)) +
	geom_violin(scale = "width") + geom_jitter(alpha=0.25) +
#	geom_smooth(se = FALSE) +
#	geom_line(data = mean_variance, aes(x = interval, y = mean), color = "blue") +
#	scale_x_continuous(transform = "log2", breaks = seq(1000, 32000, by=1000),
#		labels = c("1000", "2000", "", "4000", rep("", 3), "8000", rep("", 7), "16000", rep("", 15), "32000")) +
	scale_x_continuous(breaks = c()) +
	facet_grid(cols = vars(interval), labeller = labeller(interval = \(xs)label_comma()(map_vec(xs, as.integer)))) +
	labs(x = "Interval Size (instructions)", y = "Variance of Cluster Point's IPC") +
	theme_few() + scale_colour_few()

ggsave("plots/variance_by_interval_ipc.svg", width=10, height=5)

# calculate weighted average
selected <- filter(data, index == 0)
weights <- read_csv("simpoints/weights.csv")
estimates <- selected %>% select(benchmark, interval, cluster, cpi, ipc) %>%
	full_join(weights) %>% group_by(benchmark, interval) %>%
	summarise(weighted_cpi = sum(cpi * weight), weighted_ipc = sum(ipc * weight))

# get baseline to compare to
baseline <- read_csv("baseline/baseline.csv")
error <- baseline %>% full_join(estimates, by = join_by(benchmark)) %>%
	mutate(cpi_error = abs(weighted_cpi - real_cpi),
	       ipc_error = abs(weighted_ipc - real_ipc),
	       cpi_percent_error = cpi_error / real_cpi,
	       ipc_percent_error = ipc_error / real_ipc)
