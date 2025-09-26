const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const PORT = 80;

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());

// Serve static files from current directory
app.use(express.static(__dirname));

// Root route
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'index.html'));
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    message: 'Bencenet Bank EaZyLinks is running'
  });
});

// API endpoints
app.post('/login', (req, res) => {
  res.json({ status: 'success', message: 'Login successful' });
});

app.post('/register', (req, res) => {
  res.json({ status: 'success', message: 'Registration successful' });
});

app.post('/send-money', (req, res) => {
  res.json({ status: 'success', message: 'Money sent successfully' });
});

app.post('/withdraw', (req, res) => {
  res.json({ status: 'success', message: 'Withdrawal successful' });
});

app.get('/account-statement', (req, res) => {
  res.json({ status: 'success', data: 'Account statement data' });
});

app.get('/account-balance', (req, res) => {
  res.json({ status: 'success', balance: '₦50,000.00' });
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Bencenet Bank app running on port ${PORT}`);
});