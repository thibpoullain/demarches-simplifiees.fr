### Le projet demat-social

##### Contexte

Le projet demat-social a été initialement forké du projet [demarches-simplifiees](https://github.com/demarches-simplifiees/demarches-simplifiees.fr).

Le projet demat-social a évolué et se différencie de trois façons distinctes:

  1. En ajoutant des fonctionnalités spécifiques à la DNUM pour une utilisation par les Ministères Sociaux (Santé et Travail) comme par exemple la gestion des données de type NIR (n° de sécurité sociale), rppsante et finess.
  2. En proposant un environnement de développement et de déploiement sous Docker.
  3. En suivant et en ré-intégrant régulièrement les évolutions de la DINUM effectuées sur demarches-simplifiees. Voir à ce sujet les [notes de releases demarches-simplifiees](https://github.com/demarches-simplifiees/demarches-simplifiees.fr/releases).

Un exemple d'utilisation de demat-social est la campagne annuelle de vaccination papillomavirus effectuée par les différentes ARS régionales.

##### Pré-requis

L'environnement de développement du projet demat-social a été testé sous Linux (Ubuntu 22.04.2 LTS), MacOS (BigSur 11.6.8) et Windows 11.

Pour installer le projet il faut disposer des *pré-requis* suivants sur sa machine de développement:

  - un terminal bash (ou compatible)
  - git
  - docker et docker-compose
  - make
  - une connexion réseau internet rapide.
  - la librairie imagemagick d'installée (et non graphicsmagick)

Il est aussi souhaitable de disposer de données représentatives de l'application en production. Pour cela on utilise un *dump anonymisé* de la base de données de production, qui peut-être simplement chargé dans l'environnement de développement. Demander ce dump anonymisé à l'un des membres de l'équipe.

Le dump anonymisé doit s'appeler `production.dump`, être décompressé, et être copié dans un répertoire `../dumps/` à un niveau au dessus du répertoire racine du projet.

```
# Exemple de structure de développement

~/dev $ tree -L 1
.
├── demat-social
├── dumps
└── tmp
```

Il est aussi utile de configurer `/etc/hosts` en y ajoutant la ligne suivante:

```
localhost       demat-dev.social.gouv.fr
```

##### Installation de l'environnement de développement

L'environnement de dévelopment en local utilise tmux avec une session préconfigurée (windows et panes pour chaque services, ngrok pour exposer le serveur à l'extérieur, etc). Vous trouverez les info dans le fichier de conf `.tmuxinator.yml`

⚠️ Allez faire un tour dans les commandes du makefile, toutes les actions utiles pour ce projet y sont documentées. Celles commençant par un "d" sont valables pour faire tourner l'application dans un environnement docker.

L'action `setup` ou `d-setup` (pour docker) fait tout pour vous 😎 (à mettre à jour si besoin).

```bash
❯ make help

 📖 Available commands

create-env-dev                 Create the .env.development file if it does not exist.
d-build-env                    Create the Docker images for demat-social and install
d-build                        Build the Docker image of the application
d-dbcreate                     Drops the current development database and create a new empty one
d-dbinit                       Reloads the database schema, runs the migrations, and seeds the database
d-dbshell-standalone           Open a bash terminal inside the app container when app is not running
d-dbshell                      Open a bash shell inside the database container when app is running
d-down                         Stop and cleanup the stopped Docker containers
d-dump                         Dump postgresql database - sql format
d-linters                      Run the linters in Docker
d-load                         Load the application database from backup - sql format
d-local-ci                     Run the local CI workflow in Docker, including linters, unit, and system tests in parallel.
d-restore_prod                 Restore the anonymized database from production - dump format
d-rspec-unit                   Run the unit tests in Docker, ex : make d-rspec-unit nb_workers=4
d-rspec                        Run the rspec tests
d-rspec_system                 Run the system tests in Docker, ex : make d-rspec_system nb_workers=4
d-setup-vite                   Sets up the Vite configuration for the Docker environment.
d-setup                        Sets up the development environment in Docker.
d-shell-root                   Open a bash shell inside the app container as root when app is running
d-shell-standalone             open a standalone web container with the app
d-shell                        Open a bash shell inside the app container when app is running
d-status                       List Docker containers
d-up                           Starts the Docker environment with the application and database services.
d-workers                      Start the background jobs (workers and periodic jobs)
dbdump-dev                     Dumps the current state of the development database into log/backup.sql.
dbload-dev                     Loads a previously dumped SQL file into the development database.
dbload-prod                    Loads a production database dump into the development environment.
dblocal                        Controls the local database service to either start or stop.
dbreset                        Resets the development database to its initial state and sets up the necessary database structures.
down                           Stop all (or per service with arg proc=service_name) the local services needed to run the app
help                           Display this help section, or the detail of a specific command : make help cmd=<command_name>
linters                        Runs lint checks on the codebase.
local-ci                       Runs the entire local CI workflow, invoking linting, unit, and system tests in parallel.
restart                        Restart all (or per service with arg proc=service_name) the local services needed to run the app
rspec-parallel-file            Executes RSpec tests in parallel on a specific file, enhancing test execution speed by distributing workload.
rspec-system-file              Runs a specified RSpec test file without the headless mode, useful for quick checks or during development.
rspec-system-visual            Executes a single system test file in a visual mode, allowing browsers to be visible during the test which aids in debugging.
rspec-system                   Executes system tests using the parallel_rspec tool, effectively speeding up testing by running multiple tests in parallel.
rspec-unit                     Executes unit tests using the parallel_rspec tool to speed up the test process.
setup-vite                     Setup the Vite configuration for the local environment, desactivate the docker configuration.
setup                          Setup the local development environment.
up                             lauch all (or per service with arg proc=service_name) the local services needed to run the app
use-dbdev                      Sets the database connection in the .env.development back to the default development database.
use-dbprod                     Switches the connection string in the .env.development to use the production dump database.
```

Pour avoir plus d'information sur une commande, renseigner largument "cmd" :

```bash
❯ make help cmd=setup

 📖 Detail of the command

setup: ## Setup the local development environment.
# This command installs necessary tools like tmux, ngrok, ImageMagick, PostgreSQL, PostGIS, and other dependencies.
# It also sets up the Ruby and Node.js environments, initializes the database with schemas and seeds, and installs all necessary gems and npm packages.
#
        @gem install bundler --conservative
        @bundle check || bundle install -j
        @node --version
        @yarn install
        @bundle exec rails db:setup
        @$(INSTALL_CMD) tmux overmind

```

Les seeds créent un user :

email:
password:

##### Tips post installation :

- Désactiver les messages de skylight qui nous averti que nous sommes en dev : `skylight disable_dev_warning`
- Créer alias make pour éviter une verbositée superflue dans votre .bashrc ou .zshrc : `alias make="make --no-print-directory"`
- Les emails sont sur la route `localhost:3000/letter_opener`
- les jobs sur `localhost:3000/manager/delayed_job`
- les seeds créent un user pour vous : `test@exemple.fr` et le password : `this is a very complicated password !`

##### Capybara & les drivers chrome

Il faut absolument faire matcher les version de chromedriver et google-chrome.

Trouver la dernière version stable de chromedriver et google chrome :

https://googlechromelabs.github.io/chrome-for-testing/

Pour connaitre les version utilisées par la suite de tests, mettre ceci dans le fichier spec/support/capybara.rb

```ruby
Selenium::WebDriver.logger.level = :debug
```
exemple de log
```bash
Found chromedriver 123.0.6312.122 in PATH: /usr/bin/chromedriver
chrome detected at /usr/bin/google-chrome
Running command: /usr/bin/google-chrome --version
Output: "Google Chrome 124.0.6367.60 "
Detected browser: chrome 124.0.6367.60
```

##### Ecrans de l'application demat-social au démarrage

###### Ecran d'accueil de demat-social 2.1.3
![boite email émulée](readme-1.png)

###### Formulaire de connexion de demat-social
![écran d'accueil de demat-social](./readme-2.png)

###### Demande de validation de l'utilisateur via son email
![écran d'accueil de demat-social](./readme-3.png)

###### Boite email de l'utilisateur émulée avec letter_opener
![écran d'accueil de demat-social](./readme-4.png)

###### Première connexion dans l'espace de travail demat-social
![écran d'accueil de demat-social](./readme-5.png)

##### Documentation externe

Documents OneNote qui décrivent notamment le processus de migration Dinum (demarches-simplifiées) vers Dnum (demat-social) ainsi que le benchmarking des exports:

[Migration du 17/04/2023 -01](https://msociauxfr.sharepoint.com/teams/Dmatrialisationdesdmarchessociales/_layouts/15/Doc.aspx?sourcedoc={763bbde3-afae-4f9f-85c5-19266658b82d}&action=edit&wd=target%28R%C3%A9alisation%20%28conception%2C%20d%C3%A9v%2C%20int%C3%A9gration%5C%29.one%7Cf8cdfd4c-fd3d-4b76-9058-4758a54214c4%2FVersion%20du%2017%5C%2F04%5C%2F2023%20-%2001%7Cfcddb1c1-110c-4212-8fbb-800fc4738608%2F%29&wdorigin=NavigationUrl)

[Migration du 07/06/2023 -01](https://msociauxfr.sharepoint.com/teams/Dmatrialisationdesdmarchessociales/_layouts/15/Doc.aspx?sourcedoc={763bbde3-afae-4f9f-85c5-19266658b82d}&action=edit&wd=target%28R%C3%A9alisation%20%28conception%2C%20d%C3%A9v%2C%20int%C3%A9gration%5C%29.one%7Cf8cdfd4c-fd3d-4b76-9058-4758a54214c4%2FVersion%20du%2007%5C%2F06%5C%2F2023%20-%2001%7Cee969558-a074-44bc-8a59-1398e7a7e6e6%2F%29&wdorigin=NavigationUrl)


[Tests de performance des exports](https://github.com/DNUM-SocialGouv/demat-social/blob/test-perf-exports/doc/README-benchmark.md)
