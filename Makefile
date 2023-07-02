.SILENT:

FILENAME=manuscript

pdf:
	pandoc $(FILENAME).md -s \
	-o $(FILENAME).pdf \
	-c css/github.css \
	--pdf-engine=wkhtmltopdf \
	--highlight-style espresso \
	-f gfm

html:
	pandoc $(FILENAME).md -s \
	-o $(FILENAME).html \
	-c css/github.css \
	--pdf-engine=wkhtmltopdf \
	--highlight-style espresso \
	-f gfm

sample:
	mkdir Sample
	cd Sample && \
	swift package init --type executable
