#!/bin/sh

echo "Cloning repositories..."

VSF=$HOME/vsf
ARCHITOWER=$HOME/architower
GRIXU=$HOME/grixu

# VSF
git clone git@github.com:vuestorefront/storefront-ui.git $VSF/storefront-ui

# Architower
git clone git@github.com:ArchiTower/repository.git $ARCHITOWER/repository
git clone git@github.com:ArchiTower/eslint-config-architower.git $ARCHITOWER/eslint-config-architower
git clone git@github.com:ArchiTower/prettier-config.git $ARCHITOWER/prettier-config
git clone git@github.com:ArchiTower/package-template.git $ARCHITOWER/package-template

# Grixu
git clone git@github.com:grixu/grixu.git $GRIXU/grixu
