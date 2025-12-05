-- VibeMon Database Initialization Script
-- TimescaleDB extension and schema setup

-- Create TimescaleDB extension
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create hypertable for telemetry data
-- This will be created after the telemetry table is created by the ORM
-- SELECT create_hypertable('telemetry', 'recorded_at', if_not_exists => TRUE);

-- Create continuous aggregates for statistics
-- These would be created after the main tables exist

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE vibemon TO postgres;
