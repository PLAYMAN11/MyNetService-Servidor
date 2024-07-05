const express = require('express');
const cors = require("cors");
const bodyParser = require('body-parser');
const usersRoutes = require('./Routes/usuarios.js');
const { createConnection } = require('./db.js');

const server = express()
server.use(cors());
server.use(bodyParser.json());
server.get("/", (req, res) => {
console.log("GET /");
res.send("Hola mundo");
});

const RUN = createConnection();


server.use('/usuarios', usersRoutes);



server.listen(3000, 'localhost', () => {
    console.log('Server running at http://localhost:3000');
});
module.exports = { RUN };