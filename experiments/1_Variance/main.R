library(tidyverse)
library(ggthemes)
library(scales)

library(showtext)
font.add("Latin Modern Roman", "/usr/share/fonts/OTF/lmroman12-regular.otf")
showtext.auto()

data <- read_csv("results/data.csv")
variance <- (data %>% group_by(benchmark, interval, cluster) %>% summarise(cpi_var = var(cpi), len = length(cpi), ipc_var = var(ipc)))
mean_variance_cpi <- (variance %>% group_by(interval) %>% summarise(mean = mean(cpi_var, na.rm = TRUE)))
mean_variance_ipc <- (variance %>% group_by(interval) %>% summarise(mean = mean(ipc_var, na.rm = TRUE)))

variance_by_interval <- ggplot(filter(variance, len == 10), aes(x = 0, y = ipc_var)) +
	geom_violin(scale = "width") + geom_jitter(alpha=0.25) +
#	geom_smooth(se = FALSE) +
#	geom_line(data = mean_variance, aes(x = interval, y = mean), color = "blue") +
#	scale_x_continuous(transform = "log2", breaks = seq(1000, 32000, by=1000),
#		labels = c("1000", "2000", "", "4000", rep("", 3), "8000", rep("", 7), "16000", rep("", 15), "32000")) +
	scale_x_continuous(breaks = c()) +
	facet_grid(cols = vars(interval), labeller = labeller(interval = \(xs)label_comma()(map_vec(xs, as.integer)))) +
	labs(x = "Interval Size (instructions)", y = "Variance of Cluster Point's IPC") +
	theme_few(base_family="Latin Modern Roman") + scale_colour_few()

ggsave("plots/variance_by_interval.svg", width=10, height=5)

# calculate weighted average
selected <- filter(data, index == 0)
weights <- read_csv("simpoints/weights.csv")
estimates <- selected %>% select(benchmark, interval, cluster, cpi, ipc) %>%
	full_join(weights) %>% group_by(benchmark, interval) %>%
	summarise(weighted_cpi = sum(cpi * weight), weighted_ipc = sum(ipc * weight))

# get baseline to compare to
baseline <- filter(read_csv("baseline/baseline.csv"), benchmark != "zip")
error <- baseline %>% full_join(estimates, by = join_by(benchmark)) %>%
	mutate(cpi_error = abs(weighted_cpi - real_cpi),
	       ipc_error = abs(weighted_ipc - real_ipc),
	       cpi_percent_error = cpi_error / real_cpi,
	       ipc_percent_error = ipc_error / real_ipc)

ggplot(error, aes(x = interval, y = ipc_percent_error, colour = benchmark)) +
	geom_point() + geom_line() +
	scale_y_continuous(lim = c(0, NA), labels = scales::label_percent()) +
	scale_x_continuous(labels = scales::label_comma()) +
	labs(x = "Interval Width (instructions)", y = "IPC Error", colour = "Benchmark") +
	theme_few(base_family="Latin Modern Roman") + scale_colour_few()
ggsave("plots/ipc_error_by_interval.svg", width=10, height=5)
