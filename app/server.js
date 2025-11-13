const express = require("express");
const client = require("prom-client");
const os = require("os");

const app = express();
const port = process.env.PORT || 8080;

// Create a Registry to register the metrics
const register = new client.Registry();

// Add default metrics (CPU, memory, etc.)
client.collectDefaultMetrics({ register });

// Custom metrics
const httpRequestDuration = new client.Histogram({
	name: "http_request_duration_seconds",
	help: "Duration of HTTP requests in seconds",
	labelNames: ["method", "route", "status"],
	buckets: [0.1, 0.5, 1, 2, 5],
});

const httpRequestsTotal = new client.Counter({
	name: "http_requests_total",
	help: "Total number of HTTP requests",
	labelNames: ["method", "route", "status"],
});

const appUptime = new client.Gauge({
	name: "app_uptime_seconds",
	help: "Application uptime in seconds",
});

const cpuUsageGauge = new client.Gauge({
	name: "cpu_usage_percent",
	help: "Current CPU usage percentage",
});

const memoryUsageGauge = new client.Gauge({
	name: "memory_usage_bytes",
	help: "Current memory usage in bytes",
});

const healthStatus = new client.Gauge({
	name: "app_health_status",
	help: "Application health status (1 = healthy, 0 = unhealthy)",
});

// Register custom metrics
register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(appUptime);
register.registerMetric(cpuUsageGauge);
register.registerMetric(memoryUsageGauge);
register.registerMetric(healthStatus);

// Store start time for uptime calculation
const startTime = Date.now();

// Simulate varying CPU and memory usage
function updateSystemMetrics() {
	// Mock CPU usage (varies between 20-80%)
	const baseCpu = 30;
	const variation = Math.sin(Date.now() / 10000) * 25; // Sine wave variation
	const cpuUsage = Math.max(
		0,
		Math.min(100, baseCpu + variation + Math.random() * 20)
	);
	cpuUsageGauge.set(cpuUsage);

	// Memory usage
	const memUsage = process.memoryUsage();
	memoryUsageGauge.set(memUsage.heapUsed);

	// Uptime
	appUptime.set((Date.now() - startTime) / 1000);

	// Health status (occasionally goes unhealthy for demo)
	const isHealthy = Math.random() > 0.05; // 95% healthy
	healthStatus.set(isHealthy ? 1 : 0);
}

// Update metrics every 5 seconds
setInterval(updateSystemMetrics, 5000);
updateSystemMetrics(); // Initial update

// Middleware to track request metrics
app.use((req, res, next) => {
	const start = Date.now();

	res.on("finish", () => {
		const duration = (Date.now() - start) / 1000;
		const route = req.path;
		const method = req.method;
		const status = res.statusCode;

		httpRequestDuration.labels(method, route, status).observe(duration);

		httpRequestsTotal.labels(method, route, status).inc();
	});

	next();
});

// Routes
app.get("/", (req, res) => {
	res.json({
		message: "Demo Monitoring App",
		version: "1.0.0",
		uptime: (Date.now() - startTime) / 1000,
		timestamp: new Date().toISOString(),
	});
});

app.get("/health", (req, res) => {
	const isHealthy = healthStatus.get().values[0]?.value === 1;

	if (isHealthy) {
		res.status(200).json({
			status: "healthy",
			uptime: (Date.now() - startTime) / 1000,
			memory: process.memoryUsage(),
			timestamp: new Date().toISOString(),
		});
	} else {
		res.status(503).json({
			status: "unhealthy",
			uptime: (Date.now() - startTime) / 1000,
			error: "Service temporarily unavailable",
			timestamp: new Date().toISOString(),
		});
	}
});

// Simulate some load - creates varying response times
app.get("/load/:ms?", (req, res) => {
	const delay = parseInt(req.params.ms) || Math.floor(Math.random() * 1000);

	setTimeout(() => {
		res.json({
			message: `Simulated load with ${delay}ms delay`,
			delay: delay,
			timestamp: new Date().toISOString(),
		});
	}, delay);
});

// Metrics endpoint for Prometheus
app.get("/metrics", async (req, res) => {
	try {
		res.set("Content-Type", register.contentType);
		const metrics = await register.metrics();
		res.end(metrics);
	} catch (error) {
		res.status(500).end(error);
	}
});

// Error handling middleware
app.use((error, req, res, next) => {
	console.error("Error:", error);
	res.status(500).json({ error: "Internal server error" });
});

app.listen(port, "0.0.0.0", () => {
	console.log(`Demo app listening on port ${port}`);
	console.log(`Metrics available at: http://localhost:${port}/metrics`);
	console.log(`Health check at: http://localhost:${port}/health`);
	console.log(`Load simulation at: http://localhost:${port}/load/[ms]`);
});
