\set datapath 'D:/donnees/tisseo/20190415/'
\set schema reseau.
-- agency.txt
DROP TABLE IF EXISTS reseau.agency;
CREATE TABLE reseau.agency (
    fid serial PRIMARY KEY,
    agency_id varchar(20),
    agency_name varchar(80),
    agency_url varchar(100),
    agency_timezone varchar(20),
    agency_phone varchar(20),
    agency_lang varchar(2)
);

-- calendar.txt
DROP TABLE IF EXISTS reseau.calendar;
CREATE TABLE reseau.calendar (
    fid serial PRIMARY KEY,
    service_id varchar(20),
    monday boolean,
    tuesday boolean,
    wednesday boolean,
    thursday boolean,
    friday boolean,
    saturday boolean,
    sunday boolean,
    start_date date,
    end_date date
 );

-- calendar_dates.txt
DROP TABLE IF EXISTS reseau.calendar_dates;
CREATE TABLE reseau.calendar_dates (
    fid serial PRIMARY KEY,
    service_id varchar(20),
    "date" date,
    exception_type smallint
);

-- routes.txt
DROP TABLE IF EXISTS reseau.routes;
CREATE TABLE reseau.routes (
    fid serial PRIMARY KEY,
    route_id varchar(20),
    agency_id varchar(20),
    route_short_name varchar(5),
    route_long_name varchar(55),
    route_desc varchar(80),
    route_type smallint,
    route_url varchar(100),
    route_color varchar(6),
    route_text_color varchar(6)
);

-- shapes.txt
DROP TABLE IF EXISTS reseau.shapes;
CREATE TABLE reseau.shapes (
    fid serial PRIMARY KEY,
    shape_id varchar(20),
    shape_pt_lat real,
    shape_pt_lon real,
    shape_pt_sequence smallint
);

-- stop_times.txt
DROP TABLE IF EXISTS reseau.stop_times;
CREATE TABLE reseau.stop_times (
    fid serial PRIMARY KEY,
    trip_id varchar(20),
    stop_id varchar(20),
    stop_sequence smallint,
    arrival_time varchar(8), 
    departure_time varchar(8), 
    stop_headsign varchar(55),
    pickup_type smallint,
    drop_off_type smallint,
    shape_dist_traveled smallint
);

-- stops.txt
DROP TABLE IF EXISTS reseau.stops;
CREATE TABLE reseau.stops (
    fid serial PRIMARY KEY,
    stop_id varchar(20),
    stop_code varchar(20),
    stop_name varchar(40),
    stop_lat real,
    stop_lon real,
    location_type smallint,
    parent_station varchar(20),
    wheelchair_boarding smallint
);

-- trips
DROP TABLE IF EXISTS reseau.trips;
CREATE TABLE reseau.trips (
    fid serial PRIMARY KEY,
    trip_id varchar(20),
    service_id varchar(20),
    route_id varchar(20), 
    trip_headsign varchar(55), 
    direction_id smallint, 
    shape_id varchar(20) 
);
    
\set path :datapath 'agency.txt'
COPY :schema agency(agency_id,agency_name,agency_url,agency_timezone,agency_phone,agency_lang) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'calendar.txt'
COPY :schema calendar(service_id,monday,tuesday,wednesday,thursday,friday,saturday,sunday,start_date,end_date) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'calendar_dates.txt'
COPY :schema calendar_dates(service_id, "date", exception_type) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'routes.txt'
COPY :schema routes(route_id,agency_id,route_short_name,route_long_name,route_desc,route_type,route_url,route_color,route_text_color) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'shapes.txt'
COPY :schema shapes(shape_id,shape_pt_lat,shape_pt_lon,shape_pt_sequence) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'stop_times.txt'
COPY :schema stop_times(trip_id,stop_id,stop_sequence,arrival_time,departure_time,stop_headsign,pickup_type,drop_off_type,shape_dist_traveled) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'stops.txt'
COPY :schema stops(stop_id,stop_code,stop_name,stop_lat,stop_lon,location_type,parent_station,wheelchair_boarding ) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'trips.txt'
COPY :schema trips(trip_id,service_id,route_id,trip_headsign,direction_id,shape_id ) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';


-- Géometrie des stops (points)
ALTER TABLE reseau.stops ADD COLUMN geom geometry(Point,2154);
CREATE INDEX idx_reseau_stops ON reseau.stops USING gist (geom);

UPDATE reseau.stops 
    SET geom = ST_TRANSFORM(ST_SETSRID(ST_MakePoint(cast(stop_lon as float8), cast(stop_lat as float8)),4326), 2154);
    
    
-- Création d'une table lines contenant chaque route 1 fois (pas de superposition)
DROP TABLE IF EXISTS reseau.lines;

CREATE TABLE reseau.lines AS (
    -- Sélection des shapes de chaque route
    with lines as (
        select r.route_short_name, max(r.route_color) route_color, max(r.route_text_color) route_text_color, s.shape_id, count(*) nb
        from reseau.shapes s
        inner join reseau.trips t on t.shape_id = s.shape_id 
        inner join reseau.routes r on r.route_id = t.route_id
        -- where r.route_short_name IN( 'T1', 'T2', 'A', 'B')
        group by r.route_short_name, s.shape_id 
        order by r.route_short_name, nb desc
    ),
    -- Sélectionne l' itinéraire contenant le plus de segments pour une route donnée
    itis as (
        select route_short_name, max(route_color) route_color, max(route_text_color) route_text_color, max(shape_id) shape_id, max(nb) nb
        from lines l
        where nb = (select max(nb) from lines where route_short_name = l.route_short_name)
        group by route_short_name
    ),
    -- Met les segments des itinéraires dans leur ordre de passage
    orderedshapes as (
        select i.route_short_name, i.route_color, i.route_text_color, s.shape_id, cast(s.shape_pt_lon as real) lon, cast(s.shape_pt_lat as real) lat, s.shape_pt_sequence
        from reseau.shapes s
        inner join itis i on i.shape_id = s.shape_id
        order by s.shape_id, cast(s.shape_pt_sequence as integer)
    ),
    -- Création des géométries points des segments
    points as (
        select cast(shape_pt_sequence as integer) shape_pt_sequence, route_short_name, route_color, route_text_color, shape_id, st_transform(st_setsrid(st_makepoint(lon, lat),4326), 2154) geom from orderedshapes
    )
    -- création des lignes
    select st_makeline(geom)::geometry(LINESTRING,2154) geom, shape_id, MAX(route_short_name) route_short_name, max(route_color) route_color, max(route_text_color) route_text_color
    from points group by shape_id
);


ALTER TABLE reseau.lines ADD COLUMN fid SERIAL PRIMARY KEY;
CREATE INDEX lines_geom_gist ON reseau.lines USING GIST (geom);

-- un peu de nettoyage
VACUUM ANALYZE reseau.agency;
VACUUM ANALYZE reseau.calendar;
VACUUM ANALYZE reseau.calendar_dates;
VACUUM ANALYZE reseau.routes;
VACUUM ANALYZE reseau.shapes;
VACUUM ANALYZE reseau.stop_times;
VACUUM ANALYZE reseau.stops;
VACUUM ANALYZE reseau.trips;