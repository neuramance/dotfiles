### To get them, do this:
	cd ~
	git init
	git remote add origin http://github.com/hxnt/dotfiles.git
	git pull origin master

Then install [Homebrew](https://brew.sh/) and run:

	brew tap Homebrew/bundle
	brew bundle

Everything should now be installed

### Exporting Homebrew's 'Brewfile':

    brew bundle dump
