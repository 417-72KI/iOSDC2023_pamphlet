.SILENT:

FILENAME=manuscript

.PHONY: all
all: pdf html

.PHONY: pdf
pdf: lint
	pandoc $(FILENAME).md -s \
	-o $(FILENAME).pdf \
	-c css/github.css \
	--pdf-engine=wkhtmltopdf \
	--highlight-style espresso \
	-f gfm

.PHONY: html
html: lint
	pandoc $(FILENAME).md -s \
	-o $(FILENAME).html \
	-c css/github.css \
	--pdf-engine=wkhtmltopdf \
	--highlight-style espresso \
	-f gfm

.PHONY: lint
lint:
	textlint --fix .
	textlint .

.PHONY: setup
setup:
	brew install pandoc
	brew install --cask wkhtmltopdf
	npm install -g textlint \
	textlint-filter-rule-comments \
    textlint-filter-rule-whitelist \
    textlint-rule-no-dropping-the-ra \
    textlint-rule-preset-ja-spacing \
    textlint-rule-preset-ja-technical-writing
