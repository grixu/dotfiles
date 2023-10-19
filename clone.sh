#!/bin/sh

echo "Cloning repositories..."

ARCHISQUAD=$HOME/archisquad
GRIXU=$HOME/grixu

# archisquad
git clone git@github.com:archisquad/repository.git $ARCHISQUAD/repository
git clone git@github.com:archisquad/eslint-config-archisquad.git $ARCHISQUAD/eslint-config-archisquad
git clone git@github.com:archisquad/prettier-config.git $ARCHISQUAD/prettier-config
git clone git@github.com:archisquad/renovate-config.git $ARCHISQUAD/renovate-config
git clone git@github.com:archisquad/package-template.git $ARCHISQUAD/package-template

# Grixu
git clone git@github.com:grixu/grixu.git $GRIXU/grixu
