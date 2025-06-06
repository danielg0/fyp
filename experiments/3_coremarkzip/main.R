library(tidyverse)
library(scales)
library(ggthemes)

library(showtext)
font.add("Latin Modern Roman", "/usr/share/fonts/OTF/lmroman12-regular.otf")
showtext.auto()

data <- read_csv("results/results.csv")
spec_data <- read_csv("../2.1_test/results/results.csv")
data <- bind_rows(data, filter(spec_data, benchmark == "spec.x264"))

variance <- (data %>% group_by(benchmark, interval, cluster) %>% summarise(cpi_var = var(cpi), len = length(cpi), ipc_var = var(ipc), cpi_sd = sd(cpi), ipc_sd = sd(ipc)))
mean_variance <- (variance %>% group_by(interval) %>% summarise(cpi_mean = mean(cpi_var, na.rm = TRUE), ipc_mean = mean(ipc_var, na.rm = TRUE)))

# be AWARE of the filter occurring here
variance_by_interval <- ggplot(filter(variance, len == 10), aes(x = 0, y = ipc_var)) +

#	geom_violin(scale = "width") +
#	geom_hline(aes(yintercept = ipc_mean), mean_variance, colour = "red") +

	geom_boxplot(outliers = FALSE) +

	geom_jitter(alpha=0.25, width = 0.125) +
#	geom_point() +

#	geom_smooth(se = FALSE) +
#	geom_line(data = mean_variance, aes(x = interval, y = mean), color = "blue") +

#	scale_x_continuous(transform = "log2", breaks = seq(1000, 32000, by=1000),
#		labels = c("1000", "2000", "", "4000", rep("", 3), "8000", rep("", 7), "16000", rep("", 15), "32000")) +
	scale_x_continuous(breaks = c()) +
	facet_grid(cols = vars(interval), labeller = labeller(interval = \(xs)label_comma()(map_vec(xs, as.integer)))) +
	labs(x = "Interval Size (instructions)", y = "Variance of Cluster Point's IPC") +
	theme_few(base_family="Latin Modern Roman") + scale_colour_few()

ggsave("plots/variance_by_interval_ipc.svg", width=10, height=5)

# calculate weighted average
selected <- (filter(data, index == 0) %>%
# interval used for simulation interval (ie. the number of instructions executed)
# width is the group of weights we should use
# add on subsampled data
	mutate(source = "Super-sample", width = interval) %>%
# fix off-by-one in data. output folders use one-indexed gem5 checkpoint id and weights use zero-index simpoint cluster
	bind_rows(read_csv("../5_downsampling/results.csv") %>% mutate(cluster = cluster - 1, source = "Truncated", width = 4000000)) %>%
	bind_rows(read_csv("../5.1_x264/results.csv")       %>% mutate(cluster = cluster - 1, source = "Truncated", width = 4000000)))

weights <- read_csv("simpoints/weights.csv")
spec_weights <- read_csv("../2.1_test/simpoints/weights.csv")
weights <- bind_rows(weights, filter(spec_weights, benchmark == "spec.x264"))
# rename interval column as width
weights <- (mutate(weights, width = interval) %>% select(!interval))

estimates <- selected %>% select(benchmark, interval, source, width, cluster, cpi, ipc) %>%
	full_join(weights) %>% group_by(benchmark, interval, source) %>%
	summarise(weighted_cpi = sum(cpi * weight), weighted_ipc = sum(ipc * weight))

# get baseline to compare to
baseline <- read_csv("baseline/baseline.csv")
spec_baseline <- read_csv("../2.1_test/baseline/baseline.csv")
baseline <- bind_rows(baseline, filter(spec_baseline, benchmark == "spec.x264"))

error <- baseline %>% full_join(estimates, by = join_by(benchmark)) %>%
	mutate(cpi_error = abs(weighted_cpi - real_cpi),
	       ipc_error = abs(weighted_ipc - real_ipc),
	       cpi_percent_error = cpi_error / real_cpi,
	       ipc_percent_error = ipc_error / real_ipc)

ggplot(error, aes(x = interval, y = ipc_percent_error, colour = benchmark, linetype = source)) +
	geom_vline(xintercept=4000000, linetype="dotted") +
	geom_point() + geom_line() +
	scale_y_continuous(lim = c(0, NA), labels = scales::label_percent()) +
	scale_x_continuous(labels = scales::label_comma()) +
	labs(x = "Interval Width (instructions)", y = "IPC Error", colour = "Benchmark", linetype="Method") +
	theme_few(base_family="Latin Modern Roman") + scale_colour_few()
ggsave("plots/ipc_error_by_interval.svg", width=10, height=5)
