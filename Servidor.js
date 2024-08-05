const express = require('express');
const cors = require("cors");
const bodyParser = require('body-parser');
const usersRoutes = require('./Routes/usuarios.js');
const dotenv = require("dotenv").config();
const cookieParser = require('cookie-parser');
const { createConnection } = require('./db.js');
const Tokken = process.env.jwtSecret;
const server = express()
server.use(cors(
    {
        origin: 'https://mynetservice.store/',
        credentials: true,
    }
));
server.use(cookieParser());
server.use(bodyParser.json());
server.set('view engine', 'ejs');
server.engine('ejs', require('ejs').__express);
const RUN = createConnection(); 



server.use('/usuarios', usersRoutes);

server.get('/headermain', (req, res) => {
  res.render('partials/headermain');
});
server.get('/headermaintr', (req, res) => {
    res.render('partials/headermaintr');
  });
  
server.listen(3000, 'localhost', () => {
    console.log('Server running at http://localhost:3000'); 
    
});

module.exports = { RUN };