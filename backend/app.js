const express = require('express');
const app = express();

app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        version: '1.0',
        message: 'Backend is running!'
    });
});

app.listen(3000, () => {
    console.log('Backend running on port 3000');
});