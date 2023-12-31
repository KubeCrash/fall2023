CREATE DATABASE the_world;
USE the_world;



ALTER DATABASE the_world SET PRIMARY REGION "us-east";
ALTER DATABASE the_world ADD REGION "us-west";
ALTER DATABASE the_world ADD REGION "eu-central";

SET enable_super_regions = 'on';
ALTER DATABASE the_world ADD SUPER REGION "na" VALUES "us-east", "us-west";
ALTER DATABASE the_world ADD SUPER REGION "eu" VALUES "eu-central";


CREATE TABLE connections (
  "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  "src" TEXT NOT NULL,
  "dest" TEXT NOT NULL
) LOCALITY REGIONAL BY ROW;

CREATE TABLE cells (
  "name" TEXT PRIMARY KEY,
  "smiley" TEXT NOT NULL
) LOCALITY REGIONAL BY ROW;

CREATE TABLE visits (
  "cell_name" TEXT NOT NULL,
  "timestamp" TIMESTAMPTZ NOT NULL DEFAULT now()
) LOCALITY REGIONAL BY ROW;


CREATE OR REPLACE FUNCTION user_to_db_region(region TEXT) RETURNS CRDB_INTERNAL_REGION IMMUTABLE LEAKPROOF LANGUAGE SQL AS $$
  SELECT CASE
    WHEN lower(region) = 'na' THEN 'us-east'::CRDB_INTERNAL_REGION
    WHEN lower(region) = 'eu' THEN 'eu-central'::CRDB_INTERNAL_REGION
    ELSE 'us-east'::CRDB_INTERNAL_REGION
  END;
$$;

SELECT user_to_db_region('NA');
SELECT user_to_db_region('EU');

CREATE OR REPLACE FUNCTION db_to_user_region(region CRDB_INTERNAL_REGION) RETURNS STRING IMMUTABLE LEAKPROOF LANGUAGE SQL AS $$
  SELECT CASE
    WHEN region::STRING IN ('us-east', 'us-west') THEN 'NA'
    WHEN region::STRING = 'eu-central' THEN 'EU'
    ELSE 'NA'
  END;
$$;

SELECT db_to_user_region('us-east');
SELECT db_to_user_region('us-west');
SELECT db_to_user_region('eu-central');


CREATE USER world_service WITH PASSWORD 'EcSljwBeVIG42KLO0LS3jtuh9x6RMcOBZEWFSk';
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO world_service;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO world_service;


INSERT INTO connections (src, dest, crdb_region) VALUES
  ('eu17', 'eu11', 'eu-central'),
  ('eu17', 'eu23', 'eu-central'),
  ('eu17', 'eu16', 'eu-central'),
  ('eu18', 'eu12', 'eu-central'),
  ('eu18', 'eu24', 'eu-central'),
  ('eu18', 'eu19', 'eu-central'),
  ('na06', 'na00', 'us-east'),
  ('na06', 'na12', 'us-east'),
  ('na06', 'na07', 'us-east'),
  ('na22', 'na16', 'us-east'),
  ('na22', 'na28', 'us-east'),
  ('na22', 'na21', 'us-east'),
  ('na22', 'na23', 'us-east'),
  ('na31', 'na25', 'us-east'),
  ('na31', 'na30', 'us-east'),
  ('na31', 'na32', 'us-east'),
  ('na18', 'na12', 'us-east'),
  ('na18', 'na24', 'us-east'),
  ('na18', 'na19', 'us-east'),
  ('na27', 'na21', 'us-east'),
  ('na27', 'na33', 'us-east'),
  ('na27', 'na26', 'us-east'),
  ('na27', 'na28', 'us-east'),
  ('na28', 'na22', 'us-east'),
  ('na28', 'na34', 'us-east'),
  ('na28', 'na27', 'us-east'),
  ('na28', 'na29', 'us-east'),
  ('eu09', 'eu03', 'eu-central'),
  ('eu09', 'eu15', 'eu-central'),
  ('eu09', 'eu08', 'eu-central'),
  ('eu09', 'eu10', 'eu-central'),
  ('eu14', 'eu08', 'eu-central'),
  ('eu14', 'eu20', 'eu-central'),
  ('eu14', 'eu13', 'eu-central'),
  ('eu14', 'eu15', 'eu-central'),
  ('eu16', 'eu10', 'eu-central'),
  ('eu16', 'eu22', 'eu-central'),
  ('eu16', 'eu15', 'eu-central'),
  ('eu16', 'eu17', 'eu-central'),
  ('eu32', 'eu26', 'eu-central'),
  ('eu32', 'eu31', 'eu-central'),
  ('eu32', 'eu33', 'eu-central'),
  ('na11', 'na05', 'us-east'),
  ('na11', 'na17', 'us-east'),
  ('na11', 'na10', 'us-east'),
  ('na11', 'eu00', 'eu-central'),
  ('na11', 'eu06', 'eu-central'),
  ('na11', 'eu12', 'eu-central'),
  ('na13', 'na07', 'us-east'),
  ('na13', 'na19', 'us-east'),
  ('na13', 'na12', 'us-east'),
  ('na13', 'na14', 'us-east'),
  ('na29', 'na23', 'us-east'),
  ('na29', 'na35', 'us-east'),
  ('na29', 'na28', 'us-east'),
  ('eu15', 'eu09', 'eu-central'),
  ('eu15', 'eu21', 'eu-central'),
  ('eu15', 'eu14', 'eu-central'),
  ('eu15', 'eu16', 'eu-central'),
  ('eu19', 'eu13', 'eu-central'),
  ('eu19', 'eu25', 'eu-central'),
  ('eu19', 'eu18', 'eu-central'),
  ('eu19', 'eu20', 'eu-central'),
  ('eu26', 'eu20', 'eu-central'),
  ('eu26', 'eu32', 'eu-central'),
  ('eu26', 'eu25', 'eu-central'),
  ('eu26', 'eu27', 'eu-central'),
  ('eu33', 'eu27', 'eu-central'),
  ('eu33', 'eu32', 'eu-central'),
  ('eu33', 'eu34', 'eu-central'),
  ('eu35', 'eu29', 'eu-central'),
  ('eu35', 'eu34', 'eu-central'),
  ('na23', 'na17', 'us-east'),
  ('na23', 'na29', 'us-east'),
  ('na23', 'na22', 'us-east'),
  ('eu10', 'eu04', 'eu-central'),
  ('eu10', 'eu16', 'eu-central'),
  ('eu10', 'eu09', 'eu-central'),
  ('eu10', 'eu11', 'eu-central'),
  ('eu11', 'eu05', 'eu-central'),
  ('eu11', 'eu17', 'eu-central'),
  ('eu11', 'eu10', 'eu-central'),
  ('eu08', 'eu02', 'eu-central'),
  ('eu08', 'eu14', 'eu-central'),
  ('eu08', 'eu07', 'eu-central'),
  ('eu08', 'eu09', 'eu-central'),
  ('na07', 'na01', 'us-east'),
  ('na07', 'na13', 'us-east'),
  ('na07', 'na06', 'us-east'),
  ('na07', 'na08', 'us-east'),
  ('na16', 'na10', 'us-east'),
  ('na16', 'na22', 'us-east'),
  ('na16', 'na15', 'us-east'),
  ('na16', 'na17', 'us-east'),
  ('na20', 'na14', 'us-east'),
  ('na20', 'na26', 'us-east'),
  ('na20', 'na19', 'us-east'),
  ('na20', 'na21', 'us-east'),
  ('na24', 'na18', 'us-east'),
  ('na24', 'na30', 'us-east'),
  ('na24', 'na25', 'us-east'),
  ('na26', 'na20', 'us-east'),
  ('na26', 'na32', 'us-east'),
  ('na26', 'na25', 'us-east'),
  ('na26', 'na27', 'us-east'),
  ('na33', 'na27', 'us-east'),
  ('na33', 'na32', 'us-east'),
  ('na33', 'na34', 'us-east'),
  ('eu06', 'eu00', 'eu-central'),
  ('eu06', 'eu12', 'eu-central'),
  ('eu06', 'eu07', 'eu-central'),
  ('eu06', 'na05', 'us-east'),
  ('eu06', 'na11', 'us-east'),
  ('eu20', 'eu14', 'eu-central'),
  ('eu20', 'eu26', 'eu-central'),
  ('eu20', 'eu19', 'eu-central'),
  ('eu20', 'eu21', 'eu-central'),
  ('na04', 'na10', 'us-east'),
  ('na04', 'na03', 'us-east'),
  ('na04', 'na05', 'us-east'),
  ('na08', 'na02', 'us-east'),
  ('na08', 'na14', 'us-east'),
  ('na08', 'na07', 'us-east'),
  ('na08', 'na09', 'us-east'),
  ('na14', 'na08', 'us-east'),
  ('na14', 'na20', 'us-east'),
  ('na14', 'na13', 'us-east'),
  ('na14', 'na15', 'us-east'),
  ('eu25', 'eu19', 'eu-central'),
  ('eu25', 'eu31', 'eu-central'),
  ('eu25', 'eu24', 'eu-central'),
  ('eu25', 'eu26', 'eu-central'),
  ('na00', 'na06', 'us-east'),
  ('na00', 'na01', 'us-east'),
  ('na01', 'na07', 'us-east'),
  ('na01', 'na00', 'us-east'),
  ('na01', 'na02', 'us-east'),
  ('eu07', 'eu01', 'eu-central'),
  ('eu07', 'eu13', 'eu-central'),
  ('eu07', 'eu06', 'eu-central'),
  ('eu07', 'eu08', 'eu-central'),
  ('eu05', 'eu11', 'eu-central'),
  ('eu05', 'eu04', 'eu-central'),
  ('na02', 'na08', 'us-east'),
  ('na02', 'na01', 'us-east'),
  ('na02', 'na03', 'us-east'),
  ('na17', 'na11', 'us-east'),
  ('na17', 'na23', 'us-east'),
  ('na17', 'na16', 'us-east'),
  ('na21', 'na15', 'us-east'),
  ('na21', 'na27', 'us-east'),
  ('na21', 'na20', 'us-east'),
  ('na21', 'na22', 'us-east'),
  ('na32', 'na26', 'us-east'),
  ('na32', 'na31', 'us-east'),
  ('na32', 'na33', 'us-east'),
  ('na35', 'na29', 'us-east'),
  ('na35', 'na34', 'us-east'),
  ('na35', 'eu30', 'eu-central'),
  ('eu29', 'eu23', 'eu-central'),
  ('eu29', 'eu35', 'eu-central'),
  ('eu29', 'eu28', 'eu-central'),
  ('eu00', 'eu06', 'eu-central'),
  ('eu00', 'eu01', 'eu-central'),
  ('eu00', 'na05', 'us-east'),
  ('eu00', 'na11', 'us-east'),
  ('eu01', 'eu07', 'eu-central'),
  ('eu01', 'eu00', 'eu-central'),
  ('eu01', 'eu02', 'eu-central'),
  ('eu04', 'eu10', 'eu-central'),
  ('eu04', 'eu03', 'eu-central'),
  ('eu04', 'eu05', 'eu-central'),
  ('eu34', 'eu28', 'eu-central'),
  ('eu34', 'eu33', 'eu-central'),
  ('eu34', 'eu35', 'eu-central'),
  ('na12', 'na06', 'us-east'),
  ('na12', 'na18', 'us-east'),
  ('na12', 'na13', 'us-east'),
  ('na19', 'na13', 'us-east'),
  ('na19', 'na25', 'us-east'),
  ('na19', 'na18', 'us-east'),
  ('na19', 'na20', 'us-east'),
  ('na25', 'na19', 'us-east'),
  ('na25', 'na31', 'us-east'),
  ('na25', 'na24', 'us-east'),
  ('na25', 'na26', 'us-east'),
  ('na10', 'na04', 'us-east'),
  ('na10', 'na16', 'us-east'),
  ('na10', 'na09', 'us-east'),
  ('na10', 'na11', 'us-east'),
  ('na15', 'na09', 'us-east'),
  ('na15', 'na21', 'us-east'),
  ('na15', 'na14', 'us-east'),
  ('na15', 'na16', 'us-east'),
  ('eu02', 'eu08', 'eu-central'),
  ('eu02', 'eu01', 'eu-central'),
  ('eu02', 'eu03', 'eu-central'),
  ('eu24', 'eu18', 'eu-central'),
  ('eu24', 'eu30', 'eu-central'),
  ('eu24', 'eu25', 'eu-central'),
  ('eu12', 'eu06', 'eu-central'),
  ('eu12', 'eu18', 'eu-central'),
  ('eu12', 'eu13', 'eu-central'),
  ('eu12', 'na11', 'us-east'),
  ('eu21', 'eu15', 'eu-central'),
  ('eu21', 'eu27', 'eu-central'),
  ('eu21', 'eu20', 'eu-central'),
  ('eu21', 'eu22', 'eu-central'),
  ('eu30', 'eu24', 'eu-central'),
  ('eu30', 'eu31', 'eu-central'),
  ('eu30', 'na35', 'us-east'),
  ('eu31', 'eu25', 'eu-central'),
  ('eu31', 'eu30', 'eu-central'),
  ('eu31', 'eu32', 'eu-central'),
  ('na03', 'na09', 'us-east'),
  ('na03', 'na02', 'us-east'),
  ('na03', 'na04', 'us-east'),
  ('na05', 'na11', 'us-east'),
  ('na05', 'na04', 'us-east'),
  ('na05', 'eu00', 'eu-central'),
  ('na05', 'eu06', 'eu-central'),
  ('na09', 'na03', 'us-east'),
  ('na09', 'na15', 'us-east'),
  ('na09', 'na08', 'us-east'),
  ('na09', 'na10', 'us-east'),
  ('eu23', 'eu17', 'eu-central'),
  ('eu23', 'eu29', 'eu-central'),
  ('eu23', 'eu22', 'eu-central'),
  ('eu27', 'eu21', 'eu-central'),
  ('eu27', 'eu33', 'eu-central'),
  ('eu27', 'eu26', 'eu-central'),
  ('eu27', 'eu28', 'eu-central'),
  ('eu28', 'eu22', 'eu-central'),
  ('eu28', 'eu34', 'eu-central'),
  ('eu28', 'eu27', 'eu-central'),
  ('eu28', 'eu29', 'eu-central'),
  ('na34', 'na28', 'us-east'),
  ('na34', 'na33', 'us-east'),
  ('na34', 'na35', 'us-east'),
  ('eu13', 'eu07', 'eu-central'),
  ('eu13', 'eu19', 'eu-central'),
  ('eu13', 'eu12', 'eu-central'),
  ('eu13', 'eu14', 'eu-central'),
  ('eu22', 'eu16', 'eu-central'),
  ('eu22', 'eu28', 'eu-central'),
  ('eu22', 'eu21', 'eu-central'),
  ('eu22', 'eu23', 'eu-central'),
  ('na30', 'na24', 'us-east'),
  ('na30', 'na31', 'us-east'),
  ('eu03', 'eu09', 'eu-central'),
  ('eu03', 'eu02', 'eu-central'),
  ('eu03', 'eu04', 'eu-central');