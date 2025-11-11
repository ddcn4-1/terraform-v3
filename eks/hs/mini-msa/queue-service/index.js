require('dotenv').config();
const express = require('express');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3001;
const SERVICE_NAME = process.env.SERVICE_NAME || 'queue-service';

// Middleware
app.use(cors());
app.use(express.json());

// In-memory queue storage
const queue = [];
let jobIdCounter = 1;

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
    queueSize: queue.length
  });
});

// Get all jobs in queue
app.get('/api/queue', (req, res) => {
  res.json({
    service: SERVICE_NAME,
    totalJobs: queue.length,
    jobs: queue
  });
});

// Add job to queue
app.post('/api/queue', (req, res) => {
  const { type, data, priority = 'normal' } = req.body;

  if (!type || !data) {
    return res.status(400).json({
      error: 'Missing required fields: type, data'
    });
  }

  const job = {
    id: jobIdCounter++,
    type,
    data,
    priority,
    status: 'queued',
    createdAt: new Date().toISOString(),
    processedAt: null
  };

  queue.push(job);

  console.log(`[${SERVICE_NAME}] Job added to queue:`, job.id);

  res.status(201).json({
    message: 'Job added to queue',
    job
  });
});

// Process next job (simulate job processing)
app.post('/api/queue/process', (req, res) => {
  if (queue.length === 0) {
    return res.status(404).json({
      message: 'No jobs in queue'
    });
  }

  // Get highest priority job or first job
  const jobIndex = queue.findIndex(j => j.priority === 'high') !== -1
    ? queue.findIndex(j => j.priority === 'high')
    : 0;

  const job = queue[jobIndex];
  job.status = 'processing';

  console.log(`[${SERVICE_NAME}] Processing job:`, job.id);

  // Simulate processing
  setTimeout(() => {
    job.status = 'completed';
    job.processedAt = new Date().toISOString();
    queue.splice(jobIndex, 1);

    console.log(`[${SERVICE_NAME}] Job completed:`, job.id);
  }, 1000);

  res.json({
    message: 'Job processing started',
    job
  });
});

// Get job by ID
app.get('/api/queue/:id', (req, res) => {
  const jobId = parseInt(req.params.id);
  const job = queue.find(j => j.id === jobId);

  if (!job) {
    return res.status(404).json({
      error: 'Job not found'
    });
  }

  res.json({ job });
});

// Clear queue
app.delete('/api/queue', (req, res) => {
  const clearedCount = queue.length;
  queue.length = 0;

  console.log(`[${SERVICE_NAME}] Queue cleared: ${clearedCount} jobs removed`);

  res.json({
    message: 'Queue cleared',
    clearedJobs: clearedCount
  });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[${SERVICE_NAME}] Server running on port ${PORT}`);
  console.log(`[${SERVICE_NAME}] Environment: ${process.env.NODE_ENV || 'development'}`);
});
