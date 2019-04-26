\set datapath 'D:/donnees/gtfs/20190401_cd31/'
\set schema reseaubus.
-- agency.txt
DROP TABLE IF EXISTS :schema agency CASCADE;
CREATE TABLE :schema agency (
    fid serial NOT NULL,
    agency_id varchar(20) PRIMARY KEY,
    agency_name varchar(80),
    agency_url varchar(100),
    agency_timezone varchar(20),
    agency_lang varchar(2),
    agency_phone varchar(20),
    agency_fare_url varchar(100)
);

-- calendar.txt
DROP TABLE IF EXISTS :schema calendar CASCADE;
CREATE TABLE :schema calendar (
    fid serial NOT NULL,
    service_id varchar(20) PRIMARY KEY,
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
DROP TABLE IF EXISTS :schema calendar_dates CASCADE;
CREATE TABLE :schema calendar_dates (
    fid serial NOT NULL,
    service_id varchar(20) REFERENCES :schema calendar (service_id),
    "date" date,
    exception_type smallint,
    CONSTRAINT calendar_dates_pkey PRIMARY KEY(service_id,"date")
);

-- routes.txt
DROP TABLE IF EXISTS :schema routes CASCADE;
CREATE TABLE :schema routes (
    fid serial NOT NULL,
    route_id varchar(20) PRIMARY KEY,
    agency_id varchar(20) REFERENCES :schema agency(agency_id),
    route_short_name varchar(5),
    route_long_name varchar(55),
    route_desc varchar(80),
    route_type smallint,
    route_url varchar(100),
    route_color varchar(6),
    route_text_color varchar(6)
);

-- shapes.txt
DROP TABLE IF EXISTS :schema shapes CASCADE;
CREATE TABLE :schema shapes (
    fid serial NOT NULL,
    shape_id varchar(20),
    shape_pt_lat real,
    shape_pt_lon real,
    shape_pt_sequence smallint,
    CONSTRAINT shapes_pkey PRIMARY KEY (shape_id, shape_pt_sequence)
);

-- stop_times.txt
DROP TABLE IF EXISTS :schema stop_times CASCADE;
CREATE TABLE :schema stop_times (
    fid serial NOT NULL,
    trip_id varchar(20) REFERENCES :schema trips (trip_id),
    arrival_time varchar(8), 
    departure_time varchar(8), 
    stop_id varchar(20) REFERENCES :schema stops (stop_id),
    stop_sequence smallint,
    stop_headsign varchar(55),
    pickup_type smallint,
    drop_off_type smallint,
    shape_dist_traveled real,
    timepoint smallint,
    CONSTRAINT stop_times_pkey PRIMARY KEY (trip_id, stop_id, stop_sequence)
);

-- stops.txt
DROP TABLE IF EXISTS :schema stops CASCADE;
CREATE TABLE :schema stops (
    fid serial NOT NULL,
    stop_id varchar(20) PRIMARY KEY,
    stop_code varchar(20),
    stop_name varchar(80),
    stop_desc varchar(80),
    stop_lat real,
    stop_lon real,
    zone_id smallint,
    stop_url varchar(100),
    location_type smallint,
    parent_station varchar(20),
    stop_timezone varchar(20),
    wheelchair_boarding smallint
);

-- trips
DROP TABLE IF EXISTS :schema trips CASCADE;
CREATE TABLE :schema trips (
    fid serial NOT NULL,
    route_id varchar(20) REFERENCES :schema routes (route_id), 
    service_id varchar(20) REFERENCES :schema calendar (service_id),
    trip_id varchar(20) PRIMARY KEY,
    trip_headsign varchar(55), 
    trip_short_name varchar(10),
    direction_id smallint,
    block_id smallint,
    shape_id varchar(20),
    wheelchair_accessible smallint,
    bikes_allowed smallint    
);

    
\set path :datapath 'agency.txt'
COPY :schema agency(agency_id,agency_name,agency_url,agency_timezone,agency_lang,agency_phone,agency_fare_url) 
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
COPY :schema stop_times(trip_id,arrival_time,departure_time,stop_id,stop_sequence,stop_headsign,pickup_type,drop_off_type,shape_dist_traveled,timepoint) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'stops.txt'
COPY :schema stops(stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon,zone_id,stop_url,location_type,parent_station,stop_timezone,wheelchair_boarding )
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';

\set path :datapath 'trips.txt'
COPY :schema trips(route_id,service_id,trip_id,trip_headsign,trip_short_name,direction_id,block_id,shape_id,wheelchair_accessible,bikes_allowed ) 
FROM :'path' DELIMITER ',' CSV HEADER ENCODING 'UTF-8';


-- Géometrie des stops (points)
ALTER TABLE :schema stops ADD COLUMN geom geometry(Point,2154);
CREATE INDEX idx_reseau_stops ON :schema stops USING gist (geom);

UPDATE :schema stops 
    SET geom = ST_TRANSFORM(ST_SETSRID(ST_MakePoint(cast(stop_lon as float8), cast(stop_lat as float8)),4326), 2154);
    
    
/* --- Création de shapes_geom -> 1 géométrie / shape_id --- */
DROP TABLE IF EXISTS :schema shapes_geom CASCADE;
CREATE TABLE :schema shapes_geom AS (
	with ordered_shapes as(
	select st_transform(st_setsrid(st_makepoint(shape_pt_lon, shape_pt_lat),4326), 2154)::geometry(point, 2154) geom, shape_id, shape_pt_lat, shape_pt_lon, shape_pt_sequence 
	from :schema shapes
	order by shape_id, shape_pt_sequence)

	select st_makeline(geom)::geometry(linestring, 2154) geom, shape_id 
	from ordered_shapes 
	group by shape_id
);

ALTER TABLE :schema shapes_geom ADD PRIMARY KEY(shape_id);
CREATE INDEX shapes_geom_gist ON :schema shapes_geom USING GIST (geom);

ALTER TABLE :schema shapes ADD CONSTRAINT fkshapes_shapes_geom FOREIGN KEY (shape_id) REFERENCES :schema shapes_geom (shape_id);
ALTER TABLE :schema trips ADD CONSTRAINT fktrips_shapes_geom FOREIGN KEY (shape_id)  REFERENCES :schema shapes_geom (shape_id);
    
    
-- Création d'une table lines contenant chaque route 1 fois (pas de superposition)
DROP TABLE IF EXISTS :schema lines;

CREATE TABLE :schema lines AS (
    -- Sélection des shapes de chaque route
    with lines as (
        select r.route_short_name, max(r.route_color) route_color, max(r.route_text_color) route_text_color, s.shape_id, count(*) nb
        from :schema shapes s
        inner join :schema trips t on t.shape_id = s.shape_id 
        inner join :schema routes r on r.route_id = t.route_id
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
        from :schema shapes s
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


ALTER TABLE :schema lines ADD COLUMN fid SERIAL PRIMARY KEY;
CREATE INDEX lines_geom_gist ON :schema lines USING GIST (geom);

-- un peu de nettoyage
VACUUM ANALYZE :schema agency;
VACUUM ANALYZE :schema calendar;
VACUUM ANALYZE :schema calendar_dates;
VACUUM ANALYZE :schema routes;
VACUUM ANALYZE :schema shapes;
VACUUM ANALYZE :schema stop_times;
VACUUM ANALYZE :schema stops;
VACUUM ANALYZE :schema trips;
