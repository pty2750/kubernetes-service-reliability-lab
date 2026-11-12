SELECT
    scenario,
    COUNT(*) AS requests,
    COUNT_IF(http_status IS NULL OR http_status NOT BETWEEN 200 AND 299) AS errors,
    ROUND(
        100.0 * COUNT_IF(http_status IS NULL OR http_status NOT BETWEEN 200 AND 299)
        / COUNT(*),
        2
    ) AS error_rate_pct,
    ROUND(PERCENTILE(latency_ms, 0.95), 2) AS p95_latency_ms
FROM workspace.default.reliability_events
GROUP BY scenario;