# TP 6

![wordpress-logo](images/wordpress-logo.png)

**Saviez vous que [Wordpress](https://wordpress.com/fr/) est le constructeur de site internet le plus utilisé ?**
![wordpress_market](./images/wordpress_market_share.png)

-> 43% des sites internet ont été réalisés avec WordPress et 63% des blogs 🤯

Vous êtes la nouvelle / le nouveau DevOps Engineer d'une startup 👩‍💻👨‍💻
Vous avez pour objectif de configurer l'infrastructure sur GCP qui hébergera le site de l'entreprise 🌏.

Dans ce TP, l'objectif est de **déployer l'application Wordpress** sur Cloud Run puis Kubernetes en utilisant les outils et pratiques vus ensemble : git, Docker, Artifact Registry, Cloud Build, Infrastructure as Code (Terraform) et GKE.

En bon ingénieur·e DevOps, nous allons découper le travail en  3 parties. Les 2 premières sont complètement indépendantes.

## Partie 1 : Infrastructure as Code

Afin d'avoir une configuration facile à maintenir pour le futur, on souhaite utiliser Terraform pour définir l'infrastructure nécessaire à Wordpress.

**💡 Créez les relations de dépendances entre les ressources pour les créer dans le bon ordre**

Nous allons créer les ressources suivantes à l'aide de Terraform :
- Les APIs nécessaires au bon fonctionnement du projet :
  - `cloudresourcemanager.googleapis.com`
  - `serviceusage.googleapis.com`
  - `artifactregistry.googleapis.com`
  - `sqladmin.googleapis.com`
  - `cloudbuild.googleapis.com`

- Dépôt Artifact Registry avec commme repository_id : `website-tools`

- Une base de données MySQL `wordpress` : l'instance de la base de donnée `main-instance` a été crée pendant le préparation du TP avec la commande `gcloud`

- un compte utilisateur de la base de données

1. Commencer par créer le bucket GCS (Google Cloud Storage) qui servira à stocker le state Terraform.

Réponse : commande gcloud storage buckets create gs://terraform-devops-tp-eval --location=us-central1
Puis pour vérifier que le bucket à été crée : gcloud storage buckets list

2. Définir les éléments de base nécessaires à la bonne exécution de terraform : utiliser l'exemple sur le [repo du cours](https://github.com/aballiet/devops-dauphine-2024/tree/main/exemple/cloudbuild-terraform) si besoin pour vous aider

Réponse :  On crée un main.tf

3. Afin de créer la base de données, utiliser la documentation [SQL Database](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_database) et enfin un [SQL User](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/sql_user)
   1. Pour `google_sql_database`, définir `name="wordpress"` et `instance="main-instance"`
   2. Pour `google_sql_user`, définissez le comme ceci :
      ```hcl
      resource "google_sql_user" "wordpress" {
         name     = "wordpress"
         instance = "main-instance"
         password = "ilovedevops"
      }
      ```
4. Lancer `terraform plan`, vérifier les changements puis appliquer les changements avec `terraform apply`

Réponse : on lance terraform init avant, puis plan et apply. 

5. Vérifier que notre utilisateur existe bien : https://console.cloud.google.com/sql/instances/main-instance/users (veiller à bien séléctionner le projet GCP sur lequel vous avez déployé vos ressources)

Réponse : on a bien notre utilisateur wordpress !
![alt text](images/image.png)

6. Rendez-vous sur https://console.cloud.google.com/sql/instances/main-instance/databases. Quelles sont les base de données présentes sur votre instance `main-instance` ? Quels sont les types ?

Réponse : `main-instance` à les bases de données :

| Nom de la base de données | Interclassement | Encodage | Type |
|---------------------------|-----------------|----------|------|
| information_schema         | utf8mb3_general_ci | utf8mb3 | Système |
| mysql                      | utf8mb3_general_ci | utf8mb3 | Système |
| performance_schema         | utf8mb4_0900_ai_ci | utf8mb4 | Système |
| sys                        | utf8mb4_0900_ai_ci | utf8mb4 | Système |
| wordpress                  | utf8mb3_general_ci | utf8mb3 | Utilisateur |

On a déjà différentes bases de données système qui gère le fonctionnement de MySQL :
   - `information_schema` : Contient des métadonnées sur toutes les bases de données et tables
   - `mysql` : Stocke les informations des comptes utilisateurs et les permissions
   - `performance_schema` : Utilisée pour surveiller et optimiser les performances de MySQL
   - `sys` : Fournit des vues simplifiées pour mieux comprendre l’état et la performance du serveur

Puis on a notre db crée à l'étape précédente : 
   - `wordpress` : Base de données dédiée au site WordPress. Elle stocke les articles, utilisateurs, paramètres et plugins de WordPress.

## Partie 2 : Docker

Wordpress dispose d'une image Docker officielle disponible sur [DockerHub](https://hub.docker.com/_/wordpress)

1. Récupérer l'image sur votre machine (Cloud Shell)

Réponse : docker pull wordpress
On vérifie qu'on à bien notre image de téléchargé en faisant docker images 
![alt text](images/docker_image.png)

2. Lancer l'image docker et ouvrez un shell à l'intérieur de votre container:

Réponse : on run : docker run -d --name wp-container wordpress
Valeur de retour : f71752cf6e5500898346fd4546b03be0429fd0cc4d7f85d29b0ea31a2376d895
On vérifie que notre container est bien lancé avec docker ps
![alt text](images/run_docker.png)
On lance un shell à l'intérieur du containeur : docker exec -it wp-container /bin/bash

   1. Quel est le répertoire courant du container (WORKDIR) ?

   Réponse : Une fois le shell du container lancé on run pwd et on obtient le répertoire courant : /var/www/html 
   qui est bien le WORKDIR de notre image wordpress

   2. Quelles sont les différents fichiers html contenu dans WORKDIR ?

   Réponse : on peut faire la commande ls -l *.html pour avoir tous les fichiers html du workdir, on a uniquement le readme.html, le reste des fichiers sont des fichiers php (on voit ça avec la commande ls -l)

   ![alt text](images/workdir.png)

3. Supprimez le container puis relancez en un en spécifiant un port binding (une correspondance de port).

   Réponse : on sort du shell avec la commande exit, puis on arrête le conainer avec la commande docker stop wp-container 
   et on le supprime avec docker rm wp-container
   On vérifie avec docker ps que nous n'avon plus rien en court d'exécution

   1. Vous devez pouvoir communiquer avec le port par défaut de wordpress : **80** (choisissez un port entre 8000 et 9000 sur votre machine hôte => cloudshell)

   Réponse : pour cela on run la commande docker run -d --name wp-container -p 8090:80 wordpress
   ![alt text](images/port_binding.png)

   2. Avec la commande `curl`, faites une requêtes depuis votre machine hôte à votre container wordpress. Quelle est la réponse ? (il n'y a pas piège, essayez sur un port non utilisé pour constater la différence)

   Réponse : il n'y a pas de valeur de réponse lorsque qu'on effectue curl http://localhost:8090 mais lorsque nous essayons un autre port curl http://localhost:8080 nous avons la réponse 'curl: (7) Failed to connect to localhost port 8080 after 0 ms: Couldn't connect to server'

   3. Afficher les logs de votre container après avoir fait quelques requêtes, que voyez vous ?

   Réponse : après quelques requêtes on peut constater dans les logs que nous avons bien envoyé une réquête au server 
   ![alt text](images/logs.png)

   4. Utilisez l'aperçu web pour afficher le résultat du navigateur qui se connecte à votre container wordpress
      1. Utiliser la fonction `Aperçu sur le web`
        ![web_preview](images/wordpress_preview.png)
      2. Modifier le port si celui choisi n'est pas `8000`
      3. Une fenètre s'ouvre, que voyez vous ?

   Réponse : On tombe bien sur la page html de wordpress (qui est l'ux/ui des fichiers php qu'on a vu plus tôt dans le workdir)
   ![alt text](images/wordpress_ux.png)

4. A partir de la documentation, remarquez les paramètres requis pour la configuration de la base de données.

Réponse : On note les variables d’environnement requises pour que WordPress puisse se connecter à MySQL
- WORDPRESS_DB_HOST → Adresse du serveur MySQL
- WORDPRESS_DB_USER → Nom d'utilisateur MySQL
- WORDPRESS_DB_PASSWORD → Mot de passe MySQL
- WORDPRESS_DB_NAME → Nom de la base de données WordPress

5. Dans la partie 1 du TP (si pas déjà fait), nous allons créer cette base de donnée. Dans cette partie 2 nous allons créer une image docker qui utilise des valeurs spécifiques de paramètres pour la base de données.

   1. Créer un Dockerfile

   2. Spécifier les valeurs suivantes pour la base de données à l'aide de l'instruction `ENV` (voir [ici](https://stackoverflow.com/questions/57454581/define-environment-variable-in-dockerfile-or-docker-compose)):
        - `WORDPRESS_DB_USER=wordpress`
        - `WORDPRESS_DB_PASSWORD=ilovedevops`
        - `WORDPRESS_DB_NAME=wordpress`
        - `WORDPRESS_DB_HOST=0.0.0.0`

   3. Construire l'image docker.

   Réponse : docker build -t wordpress .

   4. Lancer une instance de l'image, ouvrez un shell. Vérifier le résultat de la commande `echo $WORDPRESS_DB_PASSWORD`

   Réponse : on run l'image : docker run -d --name custom-wp-container wordpress 
   Puis on lance un shell docker exec -it custom-wp-container /bin/bash
   Et on récupère bien le password de notre db 
   ![alt text](images/password_echo.png)

6. Pipeline d'Intégration Continue (CI):
   1. Créer un dépôt de type `DOCKER` sur artifact registry (si pas déjà fait, sinon utiliser celui appelé `website-tools`)

   Réponse : normalement déjà fait dans le terraform ça donc on check avec la commande : gcloud artifacts repositories list
   ![alt text](images/website-tools.png)

   2. Créer une configuration cloudbuild pour construire l'image docker et la publier sur le depôt Artifact Registry

   Réponse : On tag notre image 
   docker tag wordpress us-central1-docker.pkg.dev/$(gcloud config get-value project)/website-tools/wordpress:latest
   docker push us-central1-docker.pkg.dev/$(gcloud config get-value project)/website-tools/wordpress:latest
   On vérifie que notre image est bien stocké : 
   gcloud artifacts docker images list us-central1-docker.pkg.dev/$(gcloud config get-value project)/website-tools

   3. Envoyer (`submit`) le job sur Cloud Build et vérifier que l'image a bien été créée

   Réponse : On crée cloudbuild.yaml et on pourra submit gcloud builds submit --config cloudbuild.yaml .
   ![alt text](images/build_cloudbuild.png)

## Partie 3 : Déployer Wordpress sur Cloud Run puis Kubernetes 🔥

Nous allons maintenant mettre les 2 parties précédentes ensemble.

Notre but, ne l'oublions pas est de déployer wordpress sur Cloud Run puis Kubernetes !

### Configurer l'adresse IP de la base MySQL utilisée par Wordpress

1. Rendez vous sur : https://console.cloud.google.com/sql/instances/main-instance/connections/summary?
   L'instance de base données dispose d'une `Adresse IP publique`. Nous allons nous servir de cette valeur pour configurer notre image docker Wordpress qui s'y connectera.

![alt text](images/image_publique.png)

2. Reprendre le Dockerfile de la [Partie 2](#partie-2--docker) et le modifier pour que `WORDPRESS_DB_HOST` soit défini avec l'`Adresse IP publique` de notre instance de base de donnée.

3. Reconstruire notre image docker et la pousser sur notre Artifact Registry en utilisant cloud build

Réponse : Une fois le Dockerfile update on push notre nouvelle image gcloud builds submit --tag us-central1-docker.pkg.dev/devops-tp-eval/website-tools/wordpress:latest . 
Pas besoin de faire un docker build en local, Cloud Build va directement prendre en compte le nouveau Dockerfile et tout reconstruire 

### Déployer notre image docker sur Cloud Run

1. Ajouter une ressource Cloud Run à votre code Terraform. Veiller à renseigner le bon tag de l'image docker que l'on vient de publier sur notre dépôt dans le champs `image` ainsi que le port utilisé par notre application.

Réponse : pour cela on modifie notre main.tf

   Afin d'autoriser tous les appareils à se connecter à notre Cloud Run, on définit les ressources :

   ```hcl
   data "google_iam_policy" "noauth" {
      binding {
         role = "roles/run.invoker"
         members = [
            "allUsers",
         ]
      }
   }

   resource "google_cloud_run_service_iam_policy" "noauth" {
      location    = google_cloud_run_service.default.location # remplacer par le nom de votre ressource
      project     = google_cloud_run_service.default.project # remplacer par le nom de votre ressource
      service     = google_cloud_run_service.default.name # remplacer par le nom de votre ressource

      policy_data = data.google_iam_policy.noauth.policy_data
   }
   ```

   ☝️ Vous aurez besoin d'activer l'API : `run.googleapis.com` pour créer la ressource de type `google_cloud_run_service`. Faites en sorte que l'API soit activé avant de créer votre instance Cloud Run 😌

   Appliquer les changements sur votre projet gcp avec les commandes terraform puis rendez vous sur https://console.cloud.google.com/run pendant le déploiement.

2. Observer les journaux de Cloud Run (logs) sur : https://console.cloud.google.com/run/detail/us-central1/serveur-wordpress/logs.
   1. Véirifer la présence de l'entrée `No 'wp-config.php' found in /var/www/html, but 'WORDPRESS_...' variables supplied; copying 'wp-config-docker.php' (WORDPRESS_DB_HOST WORDPRESS_DB_PASSWORD WORDPRESS_DB_USER)`

   ![alt text](images/entry_logs.png)

   2. Au bout de 5 min, que se passe-t-il ? 🤯🤯🤯

   Réponse : Au bout de 5 min on a le timeout qui s'active (erreur de port d'écoute de wordpress par défaut qui est le port 80) 
   Il faut donc faire un binding de port

   3. Regarder le resultat de votre commande `terraform apply` et observer les logs de Cloud Run

3. Autoriser toutes les adresses IP à se connecter à notre base MySQL (sous réserve d'avoir l'utilisateur et le mot de passe évidemment)
   1. Pour le faire, exécuter la commande
      ```bash
      gcloud sql instances patch main-instance --authorized-networks=0.0.0.0/0
      ```

5. Accéder à notre Wordpress déployé 🚀
   1. Aller sur : https://console.cloud.google.com/run/detail/us-central1/serveur-wordpress/metrics?
   2. Cliquer sur l'URL de votre Cloud Run : similaire à https://serveur-wordpress-oreldffftq-uc.a.run.app
   3. Que voyez vous ? 🙈

Réponse : on voit la page d'accueil de WordPress : le déploiement a réussi et la base de données est bien connectée.
![alt text](images/wordpress.png)


6. Afin d'avoir un déploiement plus robuste pour l'entreprise et économiser les coûts du service CloudSQL, nous allons déployer Wordpress sur Kubernetes
   1. Rajouter le provider kubernetes en dépendance dans `required_providers`
   2. Configure le provider kubernetes pour se connecter à notre cluster GKE

      ```hcl
      data "google_client_config" "default" {}

      data "google_container_cluster" "my_cluster" {
         name     = "gke-dauphine"
         location = "us-central1-a"
      }

      provider "kubernetes" {
         host                   = data.google_container_cluster.my_cluster.endpoint
         token                  = data.google_client_config.default.access_token
         cluster_ca_certificate = base64decode(data.google_container_cluster.my_cluster.master_auth.0.cluster_ca_certificate)
      }
      ```

   3. Déployer wordpress ainsi qu'une base de donnée MySQL sur le cluster GKE, vous pouvez vous aider de ChatGPT ou de la documentation officielle. Exemple de prompt: 
   ```
   Give me the terraform code to deploy wordpress on kubernetes using kubernetes provider. I want to use MySQL.
   ```
   Réponse : code dans le fichier new_main.tf

   4. Rendez vous sur l'adresse IP publique du service kubernetes Wordpress et vérifiez que Wordpress fonctionne 🔥




## BONUS : Partie 4

1. Utiliser Cloud Build pour appliquer les changements d'infrastructure
2. Quelles critiques du TP pouvez vous faire ? Quels sont les éléments redondants de notre configuration ?
   1. Quels paramètres avons nous dû recopier plusieurs fois ? Comment pourrions nous faire pour ne pas avoir à les recopier ?

   Réponse : On répète plusieurs fois  le mot de passe de la base de données, l'URL de l'image Docker, et certains paramètres dans les différentes ressources Kubernetes dans Terraform, aussi on note le mdp en clair ce qui est un problème. On a l'URL de l'image utilisée à plusieurs endroits il est possible de centraliser cette valeur dans une variable afin de ne pas la dupliquer. Aussi les paramètres liés à la connexion à la base de données (comme le mot de passe et le nom d'utilisateur) sont dupliqués dans plusieurs ressources.

   Pour ne pas les recopier on peut les mettre dans un fichier variables.tf et d'utiliser ces variables dans l’ensemble du code

   2. Quel outil pouvons nous utiliser pour déployer Wordpress sur Kubernetes ? Faites les changements nécessaires dans votre code Terraform.

   Réponse : On peut utiliser helm. 

   3. Comment pourrions nous enlever le mot de passe en clair dans notre code Terraform ? Quelle ressource Kubernetes pouvons nous utiliser pour le stocker ? Faites les changements nécessaires dans votre code Terraform.

   Réponse : On peut utiliser un Kubernetes Secret pour le mdp en clair. 
