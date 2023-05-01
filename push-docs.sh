#!/bin/sh
cd docs/build
rm .git -rf
git init .
git remote add origin git@github.com:ndgnuh/RiceBPH.git
git add .
git commit -m "$(date)"
git checkout -b 'docs'
git push origin docs -f
cd -
