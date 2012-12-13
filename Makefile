prefix ?= /usr/local

build: npm-install
	node_modules/.bin/grunt

# Build node-webkit package
# https://github.com/rogerwang/node-webkit/wiki/How-to-package-and-distribute-your-apps
nw: build
	zip -r ../${PWD##*/}.nw *

clean-nw:
	rm -r ../${PWD##*/}.nw

npm-install:
	npm install

clean:
	npm clean
	rm -rf node_modules
	rm -rf out

install-dirs:
	mkdir -p $(DESTDIR)$(prefix)/bin
	mkdir -p $(DESTDIR)$(prefix)/share/applications
	mkdir -p $(DESTDIR)/etc/xdg/autostart
	mkdir -p $(DESTDIR)/opt/webmenu

install: install-dirs
	cp -r lib node_modules bin docs scripts vendor theme styles *.js *.coffee *.json *.md *.html $(DESTDIR)/opt/webmenu
	install -o root -g root -m 644 webmenu.desktop \
		$(DESTDIR)/etc/xdg/autostart/webmenu.desktop
	install -o root -g root -m 644 webmenu-spawn.desktop \
		$(DESTDIR)$(prefix)/share/applications/webmenu-spawn.desktop
	install -o root -g root -m 755 bin/webmenu \
		$(DESTDIR)$(prefix)/bin/webmenu
	install -o root -g root -m 755 bin/webmenu-spawn \
		$(DESTDIR)$(prefix)/bin/webmenu-spawn

uninstall:
	rm $(DESTDIR)$(prefix)/bin/webmenu-spawn
	rm $(DESTDIR)$(prefix)/bin/webmenu
	rm -rf $(DESTDIR)/opt/webmenu
	rm $(DESTDIR)$(prefix)/share/applications/webmenu-spawn.desktop 
	rm $(DESTDIR)/etc/xdg/autostart/webmenu.desktop

test-client:
	grunt mocha

test-node:
	node_modules/.bin/mocha --reporter spec --compilers coffee:coffee-script tests/*test*

test: test-client test-node
