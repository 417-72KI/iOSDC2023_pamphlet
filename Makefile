FILENAME=manuscript

pdf:
	@pandoc $(FILENAME).md -s -o $(FILENAME).pdf --pdf-engine=wkhtmltopdf -f gfm