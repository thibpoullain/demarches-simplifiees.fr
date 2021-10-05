# Docker demarches-simplifiees

Le docker pour le projet [demarches-simplifiees.fr](http://demarches-simplifiees.fr "demarches-simplifiees.fr")

### Configuration docker / proxy

Depuis la DNUM, la configuration d'un proxy est nécessaire ; voir [la documentation associée](https://msociauxfr.sharepoint.com/teams/Boteoutils/_layouts/OneNote.aspx?id=%2Fteams%2FBoteoutils%2FDocuments%20partages%2FBo%C3%AEte%20%C3%A0%20outils%2FBoite%20%C3%A0%20outils&wd=target%28Technique.one%7C22D7A68B-D2C0-4BFC-B7B2-6BF2DFE1D482%2FBriques%20techniques%7C87D2ADCD-38E2-4E56-B879-66D4CB750688%2F%29)

### Construire l'image

En local, se positionner sur la branche à packager puis...

#### En dév, depuis le dernier commit

```bash
git_token=<token récupéré depuis https://gitlab.intranet.social.gouv.fr/profile/personal_access_tokens>
tag=`git log -1 --pretty=%h`
branch=`git branch --show-current`
docker build -t social-gouv-fr/demat:$tag --build-arg GITLAB_TOKEN=$git_token --build-arg BRANCHE=$branch .
```

### Une fois stabilisé, pour livraison

```bash
version=<version à init>
git_token=<token récupéré depuis https://gitlab.intranet.social.gouv.fr/profile/personal_access_tokens>
branch=`git branch --show-current`
docker build -t social-gouv-fr/demat:$version --build-arg GITLAB_TOKEN=$git_token --build-arg BRANCHE=$branch -f Dockerfile.ship .
```

### Lancer docker-compose
```bash
export GITLAB_TOKEN=<token récupéré depuis https://gitlab.intranet.social.gouv.fr/profile/personal_access_tokens>
export BRANCHE=`git branch --show-current`
docker-compose up
```

### Connecter en SSH dans le conteneur docker, setup & lancer le serveur:
```bash
docker exec -it <container name> /bin/bash

cd /ds

# Lancer le setup
bin/setup

# Lancer le serveur
bin/rails s -b 0.0.0.0
```

### Tester demarches-simplifiees
http://127.0.0.1:3000
