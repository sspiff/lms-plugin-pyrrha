

PLUGIN_NAME     := $(shell sed -n 's,.*<plugin.*name="\([^"]*\)".*,\1,p' misc/repo.xml)
PLUGIN_VERSION  := $(shell git describe)
GIT_COMMIT_DATE := $(shell env TZ= date -r `git log -1 --format="%at"` '+%Y-%m-%dT%H:%M:%S')
PLUGIN_ZIP       = lms-plugin-$(PLUGIN_NAME)-$(PLUGIN_VERSION).zip
PLUGIN_ZIPURL    = https://github.com/sspiff/lms-plugin-pyrrha/releases/download/$(PLUGIN_VERSION)/$(PLUGIN_ZIP)

OBJDIR = obj

ZIPEXTRAS += README.md
ZIPEXTRAS += LICENSE
ZIPEXTRAS += 3RDPARTY.md


.PHONY: dist
dist:
	rm -Rf $(OBJDIR)
	mkdir -p $(OBJDIR)
	# seed the plugin dir
	tar cf - plugin | (cd $(OBJDIR) && tar xf -)
	cp $(ZIPEXTRAS) $(OBJDIR)/plugin/
	# update install.xml with our version
	m4 -D__VERSION__=$(PLUGIN_VERSION) plugin/install.xml \
	  > $(OBJDIR)/plugin/install.xml
	# set all file times to the git commit date
	find $(OBJDIR)/plugin -type f | while read f; do \
	  env TZ= touch -d $(GIT_COMMIT_DATE) "$$f" ;    \
	  done
	# zip it up
	(cd $(OBJDIR)/plugin && find . -type f | sort \
	  | zip -X --names-stdin ../plugin.zip)
	# create the distribution
	mkdir -p $(OBJDIR)/dist
	cp $(OBJDIR)/plugin.zip $(OBJDIR)/dist/$(PLUGIN_ZIP)
	m4 -D__VERSION__=$(PLUGIN_VERSION)                                \
	   -D__ZIPURL__=$(PLUGIN_ZIPURL)                                  \
	   -D__SHA__=`shasum $(OBJDIR)/dist/$(PLUGIN_ZIP) | cut -d\  -f1` \
	   misc/repo.xml > $(OBJDIR)/dist/repo.xml


.PHONY: clean
clean:
	rm -Rf $(OBJDIR)

