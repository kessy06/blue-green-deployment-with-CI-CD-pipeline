const express = require('express');
const bodyParser = require('body-parser');
const path = require('path');

const app = express();
const PORT = 80;

app.use(bodyParser.urlencoded({ extended: true }));
app.use(bodyParser.json());
app.use(express.static('public'));

// Serve the main banking page
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API endpoints for banking operations
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

app.listen(PORT, () => {
    console.log(`Zenith Bank app running on port ${PORT}`);
});
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    message: 'Zenith Bank EaZyLinks is running'
  });
});
