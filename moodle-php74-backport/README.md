# Moodle PHP 7.4 Security Backport

Image PHP 7.4 compilée depuis les sources PHP pour un environnement
Moodle 3 historique.

## Source
- Projet : https://github.com/php/php-src
- Tag de départ : php-7.4.33
- Patch initial : commit 712e60f
- Correctifs de sécurité : voir security/PHP2SHELL.md

## Build
Le build doit télécharger les sources depuis une référence immuable,
vérifier leur empreinte SHA-256 et appliquer les patchs versionnés.

## Runtime
PHP-FPM est utilisé derrière Apache via proxy_fcgi.

## Limites
PHP 7.4 est une branche en fin de vie.
Cette image ne constitue pas un retour au support officiel.
