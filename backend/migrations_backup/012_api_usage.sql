-- API Usage Tracking for Performance Monitoring
-- This table stores API request metrics for analysis

CREATE TABLE api_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    status_code INT NOT NULL,
    response_time_ms INT NOT NULL,
    request_size_bytes BIGINT DEFAULT 0,
    response_size_bytes BIGINT DEFAULT 0,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for efficient querying
CREATE INDEX idx_api_usage_tenant_created ON api_usage(tenant_id, created_at DESC);
CREATE INDEX idx_api_usage_user_created ON api_usage(user_id, created_at DESC);
CREATE INDEX idx_api_usage_endpoint_created ON api_usage(endpoint, created_at DESC);
CREATE INDEX idx_api_usage_created_at ON api_usage(created_at DESC);
CREATE INDEX idx_api_usage_status_code ON api_usage(status_code) WHERE status_code >= 400;

-- Aggregated hourly stats for faster dashboard queries
CREATE TABLE api_usage_hourly (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id) ON DELETE SET NULL,
    hour_bucket TIMESTAMPTZ NOT NULL,
    endpoint VARCHAR(255) NOT NULL,
    method VARCHAR(10) NOT NULL,
    request_count BIGINT NOT NULL DEFAULT 0,
    error_count BIGINT NOT NULL DEFAULT 0,
    total_response_time_ms BIGINT NOT NULL DEFAULT 0,
    avg_response_time_ms INT NOT NULL DEFAULT 0,
    min_response_time_ms INT NOT NULL DEFAULT 0,
    max_response_time_ms INT NOT NULL DEFAULT 0,
    total_request_bytes BIGINT NOT NULL DEFAULT 0,
    total_response_bytes BIGINT NOT NULL DEFAULT 0,
    UNIQUE(tenant_id, hour_bucket, endpoint, method)
);

CREATE INDEX idx_api_usage_hourly_tenant_hour ON api_usage_hourly(tenant_id, hour_bucket DESC);
CREATE INDEX idx_api_usage_hourly_hour ON api_usage_hourly(hour_bucket DESC);
CREATE INDEX idx_api_usage_hourly_endpoint ON api_usage_hourly(endpoint, hour_bucket DESC);

-- Function to aggregate hourly stats
-- This can be called periodically by a cron job
CREATE OR REPLACE FUNCTION aggregate_api_usage_hourly()
RETURNS void AS $$
DECLARE
    last_hour TIMESTAMPTZ;
BEGIN
    last_hour := date_trunc('hour', NOW() - INTERVAL '1 hour');
    
    INSERT INTO api_usage_hourly (
        tenant_id, hour_bucket, endpoint, method,
        request_count, error_count, total_response_time_ms,
        avg_response_time_ms, min_response_time_ms, max_response_time_ms,
        total_request_bytes, total_response_bytes
    )
    SELECT 
        tenant_id,
        date_trunc('hour', created_at) as hour_bucket,
        endpoint,
        method,
        COUNT(*) as request_count,
        COUNT(*) FILTER (WHERE status_code >= 400) as error_count,
        SUM(response_time_ms) as total_response_time_ms,
        AVG(response_time_ms)::INT as avg_response_time_ms,
        MIN(response_time_ms) as min_response_time_ms,
        MAX(response_time_ms) as max_response_time_ms,
        COALESCE(SUM(request_size_bytes), 0) as total_request_bytes,
        COALESCE(SUM(response_size_bytes), 0) as total_response_bytes
    FROM api_usage
    WHERE created_at >= last_hour 
      AND created_at < last_hour + INTERVAL '1 hour'
    GROUP BY tenant_id, date_trunc('hour', created_at), endpoint, method
    ON CONFLICT (tenant_id, hour_bucket, endpoint, method)
    DO UPDATE SET
        request_count = api_usage_hourly.request_count + EXCLUDED.request_count,
        error_count = api_usage_hourly.error_count + EXCLUDED.error_count,
        total_response_time_ms = api_usage_hourly.total_response_time_ms + EXCLUDED.total_response_time_ms,
        avg_response_time_ms = ((api_usage_hourly.total_response_time_ms + EXCLUDED.total_response_time_ms) / 
                                (api_usage_hourly.request_count + EXCLUDED.request_count))::INT,
        min_response_time_ms = LEAST(api_usage_hourly.min_response_time_ms, EXCLUDED.min_response_time_ms),
        max_response_time_ms = GREATEST(api_usage_hourly.max_response_time_ms, EXCLUDED.max_response_time_ms),
        total_request_bytes = api_usage_hourly.total_request_bytes + EXCLUDED.total_request_bytes,
        total_response_bytes = api_usage_hourly.total_response_bytes + EXCLUDED.total_response_bytes;
END;
$$ LANGUAGE plpgsql;

-- Cleanup old raw data (keep 7 days of detailed logs, hourly aggregates forever)
CREATE OR REPLACE FUNCTION cleanup_old_api_usage()
RETURNS void AS $$
BEGIN
    DELETE FROM api_usage WHERE created_at < NOW() - INTERVAL '7 days';
END;
$$ LANGUAGE plpgsql;

COMMENT ON TABLE api_usage IS 'Stores raw API request metrics for analysis';
COMMENT ON TABLE api_usage_hourly IS 'Hourly aggregated API metrics for dashboard';

