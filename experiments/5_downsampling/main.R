library(tidyverse)
library(scales)
library(ggthemes)

library(showtext)
font.add("Latin Modern Roman", "/usr/share/fonts/OTF/lmroman12-regular.otf")
showtext.auto()

data <- read_csv("results.csv")
spec_data <- read_csv("../5.1_x264/results.csv")
data <- bind_rows(data, spec_data)
# fix off-by-one in data. output folders use one-indexed gem5 checkpoint id and weights use zero-index simpoint cluster
data <- (data %>% mutate(cluster = cluster - 1))

# calculate weighted average
weights <- read_csv("weights.csv")
spec_weights <- read_csv("../5.1_x264/weights.csv")
# exclude any weights from other interval lengths
weights <- (bind_rows(weights, spec_weights) %>% filter(interval == 4000000) %>% select(!interval))

estimates <- data %>% full_join(weights) %>% group_by(benchmark, interval) %>%
	summarise(weighted_cpi = sum(cpi * weight), weighted_ipc = sum(ipc * weight))

# get baseline to compare to
baseline <- read_csv("baseline.csv")
spec_baseline <- read_csv("../5.1_x264/baseline.csv")
baseline <- bind_rows(baseline, spec_baseline)

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
ggsave("plots/downsample_error.svg", width=10, height=5)
