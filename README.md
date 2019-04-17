# import_tisseo_gtfs_in_postgis
Import des données  gtfs fournis par Tisséo (Transports toulousains) dans une base de données postgis

Il faut au préalable avoir à disposition une base de données postgre/postgis pour pouvoir y importer les données.

- Sauvegarder import.sql en local.
- Décompresser le .zip (https://data.toulouse-metropole.fr/explore/dataset/tisseo-gtfs/information/) dans un répertoire.
- Editer import.sql et préciser au script ou se trouvent les données (2ème ligne de import.sql)
- Préciser dans quel schema de la base de données seront copiés les données (ne pas oublier le point après le nom) ex:"public." ou "reseau."
- Depuis une invite de commande, lancer le script: psql -U USER -d DB -f import.sql, ex: psql -U postgres -d tisseo -f import.sql

