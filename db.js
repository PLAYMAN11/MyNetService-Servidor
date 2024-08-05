const mysql = require('mysql2');

function createConnection() {
    return mysql.createConnection({
        host: '156.67.73.253',
        user: 'u359191253_Emmanuel',
        password: 'GonzHern1104',
        database: 'u359191253_MynetService',
        port: '3306',
    });
}

module.exports = { createConnection };

