# Observability

## Installation

Add to your Gemfile:

```ruby
gem 'langgraph_rb'
```

Run `bundle install`.

## Configuration

```ruby
Langgraph::Observability.configure do |c|
  c.env = ENV['RACK_ENV'] || 'development'
  c.service_name = 'langgraph'
  c.trace_sample_rate = 0.1
end
```

## Quickstart

```ruby
Langgraph::Observability::Adapters::OpenTelemetry.subscribe!
Langgraph::Observability::Adapters::Prometheus.enable!
logger = Langgraph::Observability::JsonLogger.new
logger.info 'hello'
```

## Grafana Queries

- `sum(rate(langgraph_graph_run_total[5m])) by (status)`
- `histogram_quantile(0.95, sum(rate(langgraph_graph_run_duration_ms_bucket[5m])) by (le))`

## Suggested Alerts

- `graph.failed_rate > 2% for 5m`
- `graph.run.p95 > 8s for 10m`
- `llm.error.rate > 1% for 5m`
- `checkpoint.restore.errors > 0 for 5m`
- `llm.cache.hit.rate < 40% for 15m`
