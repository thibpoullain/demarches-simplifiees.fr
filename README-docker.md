#### Installation de demat-social avec Docker en développement

Ce document décrit une procédure simplifiée d'installation et de lancement de
l'application demat-social sous Docker en environnement de développement.

Votre ordinateur de développement doit disposer de Make, Docker, et docker-compose.

La démarche utilise, dans la racine du projet, les fichiers suivants:

- Makefile
- Dockerfile
- docker-compose.yml
- .env

La procédure a été testée sous Linux (Ubuntu 22.04.2 LTS) et MacOS (BigSur 11.6.8).
Et avec GNU Make 4.3, Docker 20.10.21 et docker-compose 1.29.2.

Pour démarrer simplement, exécuter les instructions suivantes dans un terminal bash:

```bash
# Cloner le projet depuis Github.
> git clone git@github.com:DNUM-SocialGouv/demat-social.git
> cd demat-social

# Création de l'image Docker et installation du projet.
# A ne lancer qu'à la première installation.
> make install

# Installation des dépendances et initialisation de la base de données.
# A n'exécuter que lors de la première installation (recharge le schéma).
> make setup

# Démarrage de l'application demat-social.
> make run

# Pointer votre navigateur sur l'URL:
localhost:3000
# A la première connexion, les assets front (React) sont construites avec
# webpack, ce qui prend un peu de temps.

# Se connecter en tant qu'utilisateur avec les identifiants suivants:
email:    test@exemple.fr
password: this is a very complicated password !

# Arrêter l'application avec CONTROL C

# Supprimer les containeurs arrêtés.
> make clean

# Redémarrer l'application demat-social.
> make run
```

Autres commandes disponibles:

```bash
# Lister les containers chargés:
> make show

# Ouvrir un terminal dans le container principal de l'app demat-social,
# quand l'app est lancée.
> make shell

# Ouvrir un terminal dans le container principal de l'app demat-social,
# quand l'app est à l'arrêt.
> make console

# Lancer les tâches d'arrière plan (background jobs)
> make workers

# Faire un backup de la base de données dans log/
> make dump

# Recharger la dernière archive de la base de donnée log/backup.sql
# dans une base de données vide.
> make load

# Reconstruire les images.
> make build
```
