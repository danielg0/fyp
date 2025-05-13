#!/bin/sh
mkdir -p out
pandoc -so out/report.pdf report.md \
	--include-before-body=title.tex \
	--filter pandoc-fignos --filter pandoc-secnos \
	--toc --number-sections \
	--citeproc --bibliography refs.bib --csl vancouver-imperial-college-london.csl
