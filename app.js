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


app.listen(PORT, () => {
    console.log(`bencenet Bank app running on port ${PORT}`);
});
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    message: 'bencenet Bank EaZyLinks is running'
  });
});
