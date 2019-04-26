# import tisseo gtfs dans une base postgis
Import des données  gtfs fournies par Tisséo (Transports toulousains) dans une base de données postgis

Il faut au préalable avoir à disposition une base de données postgre/postgis pour pouvoir y importer les données.

- Sauvegarder import.sql en local.
- Décompresser le .zip (https://data.toulouse-metropole.fr/explore/dataset/tisseo-gtfs/information/) dans un répertoire.
- Editer import.sql et préciser au script ou se trouvent les données (2ème ligne de import.sql)
- Préciser dans quel schema de la base de données seront copiés les données (ne pas oublier le point après le nom) ex:"public." ou "reseau."
- Depuis une invite de commande, lancer le script: psql -U USER -d DB -f import.sql, ex: psql -U postgres -d tisseo -f import.sql

Le script peut fonctionner avec d'autres gtfs, mais il est nécessaire de l'adapter un peu car les structures de données varient. On ne trouve pas toujours les mêmes tables, l'ordre des champs peut varier, et tous les champs du standard ne sont pas obligatoires (https://developers.google.com/transit/gtfs/reference/).

