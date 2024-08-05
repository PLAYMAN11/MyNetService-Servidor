const express = require('express');
const cors = require("cors");
const bodyParser = require('body-parser');
const usersRoutes = require('./Routes/usuarios.js');
const dotenv = require("dotenv").config();
const cookieParser = require('cookie-parser');
const pool = require('./db.js');
const Tokken = process.env.jwtSecret;

const server = express();
server.use(cors({
    origin: 'https://integradora-hz0g.onrender.com/',
    credentials: true,
}));
server.use(cookieParser());
server.use(bodyParser.json());
server.set('view engine', 'ejs');
server.engine('ejs', require('ejs').__express);

server.use('/usuarios', usersRoutes);

server.get('/headermain', (req, res) => {
    res.render('partials/headermain');
});
server.get('/headermaintr', (req, res) => {
    res.render('partials/headermaintr');
});

// Change 'localhost' to '0.0.0.0' for external access
server.listen(3000, '0.0.0.0', () => {
    console.log('Server running at http://0.0.0.0:3000');
});

module.exports = pool;

