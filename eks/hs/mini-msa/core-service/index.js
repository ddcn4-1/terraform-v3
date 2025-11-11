require('dotenv').config();
const express = require('express');
const cors = require('cors');
const axios = require('axios');

const app = express();
const PORT = process.env.PORT || 3002;
const SERVICE_NAME = process.env.SERVICE_NAME || 'core-service';
const QUEUE_SERVICE_URL = process.env.QUEUE_SERVICE_URL || 'http://queue-service:3001';

// Middleware
app.use(cors());
app.use(express.json());

// Request logging middleware
app.use((req, res, next) => {
  console.log(`[${SERVICE_NAME}] ${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    status: 'healthy',
    timestamp: new Date().toISOString(),
    dependencies: {
      queueService: QUEUE_SERVICE_URL
    }
  });
});

// Check queue service health
app.get('/api/check-queue', async (req, res) => {
  try {
    console.log(`[${SERVICE_NAME}] Checking queue service health...`);
    const response = await axios.get(`${QUEUE_SERVICE_URL}/health`, {
      timeout: 5000
    });

    res.json({
      message: 'Queue service is healthy',
      queueService: response.data
    });
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Error checking queue service:`, error.message);
    res.status(503).json({
      error: 'Queue service unavailable',
      details: error.message
    });
  }
});

// Create and send job to queue
app.post('/api/jobs', async (req, res) => {
  const { type, data, priority } = req.body;

  if (!type || !data) {
    return res.status(400).json({
      error: 'Missing required fields: type, data'
    });
  }

  try {
    console.log(`[${SERVICE_NAME}] Sending job to queue service...`);
    const response = await axios.post(
      `${QUEUE_SERVICE_URL}/api/queue`,
      { type, data, priority },
      { timeout: 5000 }
    );

    console.log(`[${SERVICE_NAME}] Job successfully queued:`, response.data.job.id);

    res.status(201).json({
      message: 'Job sent to queue',
      job: response.data.job
    });
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Error sending job to queue:`, error.message);
    res.status(503).json({
      error: 'Failed to send job to queue',
      details: error.message
    });
  }
});

// Get all jobs from queue
app.get('/api/jobs', async (req, res) => {
  try {
    console.log(`[${SERVICE_NAME}] Fetching jobs from queue service...`);
    const response = await axios.get(`${QUEUE_SERVICE_URL}/api/queue`, {
      timeout: 5000
    });

    res.json({
      message: 'Jobs retrieved from queue',
      data: response.data
    });
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Error fetching jobs:`, error.message);
    res.status(503).json({
      error: 'Failed to fetch jobs from queue',
      details: error.message
    });
  }
});

// Process next job in queue
app.post('/api/jobs/process', async (req, res) => {
  try {
    console.log(`[${SERVICE_NAME}] Requesting job processing from queue service...`);
    const response = await axios.post(
      `${QUEUE_SERVICE_URL}/api/queue/process`,
      {},
      { timeout: 5000 }
    );

    res.json({
      message: 'Job processing initiated',
      job: response.data.job
    });
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Error processing job:`, error.message);

    if (error.response && error.response.status === 404) {
      return res.status(404).json({
        error: 'No jobs in queue',
        details: error.response.data
      });
    }

    res.status(503).json({
      error: 'Failed to process job',
      details: error.message
    });
  }
});

// Business logic example - create user and queue notification
app.post('/api/users', async (req, res) => {
  const { name, email } = req.body;

  if (!name || !email) {
    return res.status(400).json({
      error: 'Missing required fields: name, email'
    });
  }

  // Simulate user creation
  const user = {
    id: Date.now(),
    name,
    email,
    createdAt: new Date().toISOString()
  };

  console.log(`[${SERVICE_NAME}] User created:`, user.id);

  // Queue a notification job
  try {
    await axios.post(
      `${QUEUE_SERVICE_URL}/api/queue`,
      {
        type: 'send-welcome-email',
        data: { userId: user.id, email: user.email },
        priority: 'high'
      },
      { timeout: 5000 }
    );

    console.log(`[${SERVICE_NAME}] Welcome email queued for user:`, user.id);
  } catch (error) {
    console.error(`[${SERVICE_NAME}] Failed to queue welcome email:`, error.message);
    // Continue even if queueing fails
  }

  res.status(201).json({
    message: 'User created',
    user
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[${SERVICE_NAME}] Server running on port ${PORT}`);
  console.log(`[${SERVICE_NAME}] Queue service URL: ${QUEUE_SERVICE_URL}`);
  console.log(`[${SERVICE_NAME}] Environment: ${process.env.NODE_ENV || 'development'}`);
});
