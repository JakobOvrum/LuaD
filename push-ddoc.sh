#!/bin/bash
if [ "$TRAVIS_REPO_SLUG" == "JakobOvrum/LuaD" ] && [ "$TRAVIS_PULL_REQUEST" == "false" ] && [ "$TRAVIS_BRANCH" == "master" ]; then
	git clone --recursive --branch=gh-pages https://github.com/${TRAVIS_REPO_SLUG}.git gh-pages

	cd gh-pages
	git config credential.helper "store --file=.git/credentials"
	echo "https://${TOKEN}:@github.com" > .git/credentials
	git config --global user.name "travis-ci"
	git config --global user.email "travis@travis-ci.org"
	git config --global push.default simple

	echo -e "Generating DDoc...\n"
	sh ./generate.sh
	git add -f *.html
	git commit -m "Lastest documentation on successful travis build $TRAVIS_BUILD_NUMBER auto-pushed to gh-pages"
	git push
	echo -e "Published DDoc to gh-pages.\n"
fi

