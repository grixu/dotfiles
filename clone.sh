#!/bin/sh

ARCHISQUAD=$HOME/archisquad
GRIXU=$HOME/grixu

echo "Creating directories for projects"
mkdir $HOME/vsf
mkdir $ARCHISQUAD
mkdir $GRIXU

echo "Cloning repositories..."

# archisquad
git clone git@github.com:archisquad/repository.git $ARCHISQUAD/repository
git clone git@github.com:archisquad/eslint-config-archisquad.git $ARCHISQUAD/eslint-config-archisquad
git clone git@github.com:archisquad/prettier-config.git $ARCHISQUAD/prettier-config
git clone git@github.com:archisquad/renovate-config.git $ARCHISQUAD/renovate-config

# Grixu
git clone git@github.com:grixu/grixu.git $GRIXU/grixu
