const mysql = require('mysql2');

function createConnection() {
    return mysql.createConnection({
        host: 'localhost',
        user: 'root',
        password: 'root',
        database: 'MyNetService',
        port: '3306',
    });
}

module.exports = { createConnection };

