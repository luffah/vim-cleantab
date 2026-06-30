tags: docs
	vim -u NONE -c "helptags doc/ | qa!"

docs:
	vim -c "call genhelp#GenHelp('plugin/cleantab.vim') | qa!"

zip:
	mkdir cleantab; cp -r doc plugin README.md cleantab; zip -rm cleantab.zip cleantab
