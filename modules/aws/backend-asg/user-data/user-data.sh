#!/bin/bash
set -x

# Update system packages and install dependencies
apt-get update -y
apt-get install -y nodejs npm awscli postgresql-client

# Create a directory and initialize a minimal Node.js project
mkdir -p /opt/demo-app
cd /opt/demo-app
npm init -y
npm install express aws-sdk pg

# Create the server.js file (Express application)
cat << 'EOF' > /opt/demo-app/server.js
const express = require('express');
const AWS = require('aws-sdk');
const { Client } = require('pg');
const app = express();

// Environment variables (set by Terraform via template)
const SQS_URL = process.env.SQS_URL;  
const DB_HOST = process.env.DB_HOST;  
const DB_USER = 'alloy_user';
const DB_PASS = 'ChangeThisPassword123';
const DB_NAME = 'alloy_db';
const REGION  = 'us-east-1';
AWS.config.update({ region: REGION });
const sqs = new AWS.SQS();

// Main route: shows a simple HTML page with 3 buttons
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>Alloy Minimal Demo</title></head>
      <body>
        <h1>Alloy Auto Scaling Demo (SQS + RDS)</h1>
        <p><a href="/send">Send message to SQS (Scale Out)</a></p>
        <p><a href="/consume">Consume message from SQS (Scale In)</a></p>
        <p><a href="/dbtest">Test RDS Connection</a></p>
      </body>
    </html>
  `);
});

// Route to send a message to the SQS queue
app.get('/send', async (req, res) => {
  try {
    await sqs.sendMessage({
      QueueUrl: SQS_URL,
      MessageBody: 'Hello from instance ' + new Date()
    }).promise();
    res.send("Message sent successfully! Check the CloudWatch Alarm for scale out!");
  } catch (err) {
    res.status(500).send("Error sending message: " + err);
  }
});

// Route to consume (receive + delete) a single message from the queue
app.get('/consume', async (req, res) => {
  try {
    const data = await sqs.receiveMessage({
      QueueUrl: SQS_URL,
      MaxNumberOfMessages: 1,
      WaitTimeSeconds: 2
    }).promise();

    if (!data.Messages || data.Messages.length === 0) {
      return res.send("No messages available in the queue.");
    }
    const message = data.Messages[0];
    
    // Delete the message from the queue
    await sqs.deleteMessage({
      QueueUrl: SQS_URL,
      ReceiptHandle: message.ReceiptHandle
    }).promise();

    res.send("Message consumed and removed: " + message.Body);
  } catch (err) {
    res.status(500).send("Error consuming message: " + err);
  }
});

// Route to test a simple Postgres RDS connection
app.get('/dbtest', async (req, res) => {
  const client = new Client({
    host: DB_HOST,
    user: DB_USER,
    password: DB_PASS,
    database: DB_NAME
  });
  try {
    await client.connect();
    // Create or validate a basic table
    await client.query(`
      CREATE TABLE IF NOT EXISTS test_scaling (
        id SERIAL PRIMARY KEY,
        created_at TIMESTAMP DEFAULT now()
      );
    `);
    await client.end();
    res.send("Successfully connected to RDS! 'test_scaling' table is ready.");
  } catch (err) {
    res.status(500).send("Error connecting to RDS: " + err);
  }
});

app.listen(80, () => {
  console.log("Demo app is running on port 80!");
});
EOF

# Export environment variables and start the Node.js server
cat << 'EOL' >> /etc/environment
SQS_URL="${sqs_url}"
DB_HOST="${db_host}"
EOL

# Load them into the current shell
echo "export SQS_URL=\"${sqs_url}\""  >> /etc/profile
echo "export DB_HOST=\"${db_host}\""  >> /etc/profile
source /etc/profile

# Create a systemd service to run the Node.js app in the background
cat << 'SERV' > /etc/systemd/system/demoapp.service
[Unit]
Description=Alloy Demo Node App
After=network.target

[Service]
EnvironmentFile=-/etc/environment
WorkingDirectory=/opt/demo-app
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERV

# Enable and start the service
systemctl daemon-reload
systemctl enable demoapp.service
systemctl start demoapp.service

echo "Node.js demo app is configured and running!"
