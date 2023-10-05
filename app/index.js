const express = require('express');
const client = require('prom-client');
const app = express();
const port = 3000;

const collectDefaultMetrics = client.collectDefaultMetrics;
collectDefaultMetrics({ timeout: 5000 });

// Custom Metrics
const totalRequests = new client.Counter({
    name: 'total_requests',
    help: 'Total number of requests received'
});

const totalHelloWorlds = new client.Counter({
    name: 'total_hello_worlds',
    help: 'Total number of Hello World responses sent'
});

const randomValue = new client.Gauge({
    name: 'random_value',
    help: 'A random value between 0 and 1'
});

// Middleware to increment totalRequests counter for every request
app.use((req, res, next) => {
    totalRequests.inc();
    next();
});

app.get('/metrics', async (req, res) => {
    // Update the randomValue gauge with a random value between 0 and 1
    randomValue.set(Math.random());

    res.set('Content-Type', client.register.contentType);
    try {
        const metrics = await client.register.metrics();
        res.send(metrics);
    } catch (err) {
        res.status(500).send(err);
    }
});

app.get('/', (req, res) => {
    totalHelloWorlds.inc(); // Increment the Hello World counter
    res.send('Hello World!');
});

app.listen(port, () => console.log(`App listening on port ${port}!`));
