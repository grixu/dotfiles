#!/bin/sh

GRIXU=$HOME/grixu

echo "Creating directories for projects"
mkdir $HOME/vsf
mkdir $GRIXU

echo "Cloning repositories..."

# Grixu
git clone git@github.com:grixu/grixu.git $GRIXU/grixu
git clone git@github.com:teocrafters/public-talk-planner.git $GRIXU/public-talk-planner
git clone git@github.com:grixu/vidya.git $GRIXU/vidya
git clone git@github.com:grixu/cc-toolkit.git $GRIXU/cc-toolkit
