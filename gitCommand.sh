#!/bin/bash
# author: GDD
git add .
git commit -m $0
git push
hexo g -d
